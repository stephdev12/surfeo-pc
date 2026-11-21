package tunnel

import (
	"encoding/binary"
	"fmt"
	"strings"
	"sync"
	"time"

	"golang.org/x/crypto/ssh"
)

type DnsCacheItem struct {
	ExpiresAt time.Time
	Response  []byte
}

type DnsResolver struct {
	sshClient *ssh.Client
	cache     sync.Map
}

func NewDnsResolver(client *ssh.Client) *DnsResolver {
	return &DnsResolver{
		sshClient: client,
	}
}

// IsAaaaQuery checks if the DNS question is asking for an IPv6 AAAA record (QTYPE 28).
func IsAaaaQuery(query []byte) bool {
	if len(query) < 16 {
		return false
	}
	pos := 12
	for pos < len(query) && query[pos] != 0 {
		l := int(query[pos])
		if l > 63 {
			return false
		}
		pos += 1 + l
	}
	pos++ // skip 0x00 terminating root label
	if pos+4 <= len(query) {
		qtype := binary.BigEndian.Uint16(query[pos : pos+2])
		return qtype == 28 // AAAA
	}
	return false
}

// BuildNodataResponse creates a valid RFC 1035 response with NOERROR and 0 answers.
func BuildNodataResponse(query []byte) []byte {
	if len(query) < 12 {
		return nil
	}
	pos := 12
	for pos < len(query) && query[pos] != 0 {
		l := int(query[pos])
		if l > 63 {
			break
		}
		pos += 1 + l
	}
	pos++
	questionEnd := pos + 4
	if questionEnd > len(query) {
		questionEnd = len(query)
	}
	questionBytes := query[12:questionEnd]

	resp := make([]byte, 12+len(questionBytes))
	resp[0] = query[0]
	resp[1] = query[1]
	resp[2] = 0x81 // QR=1 (response), RD=1 (recursion desired)
	resp[3] = 0x80 // RA=1 (recursion available), RCODE=0 (NOERROR)
	resp[4] = 0x00
	resp[5] = 0x01 // QDCOUNT = 1
	resp[6] = 0x00
	resp[7] = 0x00 // ANCOUNT = 0 (NODATA)
	resp[8] = 0x00
	resp[9] = 0x00 // NSCOUNT = 0
	resp[10] = 0x00
	resp[11] = 0x00 // ARCOUNT = 0
	copy(resp[12:], questionBytes)
	return resp
}

func getDnsCacheKey(data []byte) string {
	if len(data) <= 12 {
		return ""
	}
	var sb strings.Builder
	pos := 12
	for pos < len(data) && data[pos] != 0 {
		l := int(data[pos])
		if l > 63 {
			return ""
		}
		if sb.Len() > 0 {
			sb.WriteByte('.')
		}
		pos++
		if pos+l > len(data) {
			return ""
		}
		sb.Write(data[pos : pos+l])
		pos += l
	}
	pos++
	if pos+4 <= len(data) {
		qtype := binary.BigEndian.Uint16(data[pos : pos+2])
		return fmt.Sprintf("%s:%d", sb.String(), qtype)
	}
	return ""
}

// Resolve processes the DNS query, honoring the AAAA filter, cache, and TCP fallback over SSH.
func (r *DnsResolver) Resolve(query []byte) []byte {
	if IsAaaaQuery(query) {
		return BuildNodataResponse(query)
	}

	cacheKey := getDnsCacheKey(query)
	if cacheKey != "" {
		if val, ok := r.cache.Load(cacheKey); ok {
			item := val.(DnsCacheItem)
			if time.Now().Before(item.ExpiresAt) {
				resp := make([]byte, len(item.Response))
				copy(resp, item.Response)
				if len(resp) >= 2 && len(query) >= 2 {
					resp[0] = query[0]
					resp[1] = query[1]
				}
				return resp
			}
		}
	}

	resp := r.queryOverTcp("1.1.1.1:53", query)
	if resp == nil {
		resp = r.queryOverTcp("8.8.8.8:53", query)
	}

	if resp != nil && cacheKey != "" {
		r.cache.Store(cacheKey, DnsCacheItem{
			ExpiresAt: time.Now().Add(5 * time.Minute),
			Response:  resp,
		})
	}
	return resp
}

func (r *DnsResolver) queryOverTcp(serverAddr string, query []byte) []byte {
	if r.sshClient == nil {
		return nil
	}
	conn, err := r.sshClient.Dial("tcp", serverAddr)
	if err != nil {
		return nil
	}
	defer conn.Close()

	_ = conn.SetDeadline(time.Now().Add(4 * time.Second))

	qLen := uint16(len(query))
	lenBuf := []byte{byte(qLen >> 8), byte(qLen & 0xFF)}
	if _, err := conn.Write(append(lenBuf, query...)); err != nil {
		return nil
	}

	respLenBuf := make([]byte, 2)
	if _, err := conn.Read(respLenBuf); err != nil {
		return nil
	}
	respLen := binary.BigEndian.Uint16(respLenBuf)
	if respLen == 0 || respLen > 4096 {
		return nil
	}

	resp := make([]byte, respLen)
	total := 0
	for total < int(respLen) {
		n, err := conn.Read(resp[total:])
		if err != nil {
			return nil
		}
		total += n
	}
	return resp
}
