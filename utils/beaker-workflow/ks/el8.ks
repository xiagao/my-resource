<ks><![CDATA[
rootpw --iscrypted $1$bPnySNFo$QCqmVA1sHhddG7v.ivCbA0

%post
##install certificate
curl -kL 'https://password.corp.redhat.com/RH-IT-Root-CA.crt' -o /etc/pki/ca-trust/source/anchors/RH-IT-Root-CA.crt
curl -kL 'https://password.corp.redhat.com/legacy.crt' -o /etc/pki/ca-trust/source/anchors/legacy.crt
curl -kL 'https://engineering.redhat.com/Eng-CA.crt' -o /etc/pki/ca-trust/source/anchors/Eng-CA.crt
update-ca-trust enable
update-ca-trust extract

## Generate 'setup_bridge.sh'
base64 -d <<EOF > /root/setup_bridge.sh
IyEvYmluL2Jhc2gKCl9zZXR1cF9icmlkZ2UoKQp7CiAgICAjR2V0IHRoZSBFdGhlcm5ldCBpbnRl
cmZhY2UKICAgIE5ERVY9JChpcCByb3V0ZSB8IGdyZXAgZGVmYXVsdCB8IGdyZXAgLVBvICcoPzw9
ZGV2ICkoXFMrKScgfCBhd2sgJ0JFR0lOeyBSUyA9ICIiIDsgRlMgPSAiXG4iIH17cHJpbnQgJDF9
JykKICAgICNHZXQgY29ubmVjdGlvbiBuYW1lCiAgICBDT05JRD0kKG5tY2xpIGRldmljZSBzaG93
ICROREVWIHwgYXdrIC1GOiAnL0dFTkVSQUwuQ09OTkVDVElPTi8ge3ByaW50ICQyfScgfCBhd2sg
J3skMT0kMX0xJykKCiAgICBubWNsaSBjb24gYWRkIHR5cGUgYnJpZGdlIGlmbmFtZSAiJEJSSURH
RV9JRk5BTUUiIGNvbi1uYW1lICIkQlJJREdFX0lGTkFNRSIgc3RwIG5vCiAgICBubWNsaSBjb24g
bW9kaWZ5ICIkQ09OSUQiIG1hc3RlciAiJEJSSURHRV9JRk5BTUUiCiAgICBubWNsaSBjb24gdXAg
IiRDT05JRCIKICAgIFsgJD8gLW5lIDAgXSAmJiBlY2hvICJOZXR3b3JrTWFuYWdlciBDb21tYW5k
IGZhaWxlZCIgJiYgZXhpdCAxCn0KCl9jaGtfYnJpZGdlX2Rldl9pcCgpCnsKICAgICMjIENoZWNr
IHdoZXRoZXIgYnJpZGdlIGRldmljZSBnZXRzIGlwIGFkZHJlc3MKICAgIFNUQVJUPWBkYXRlICsl
c2AKICAgIHdoaWxlIFsgJCgoICQoZGF0ZSArJXMpIC0gMTIwICkpIC1sdCAkU1RBUlQgXTsgZG8K
ICAgICAgICBJUF9BRERSPSQoaXAgYWRkcmVzcyBzaG93ICIkQlJJREdFX0lGTkFNRSIgfCBncmVw
ICJpbmV0XGIiIHwgYXdrICd7cHJpbnQgJDJ9JyB8IGN1dCAtZC8gLWYxKQogICAgICAgIFtbIC1u
ICIkSVBfQUREUiIgXV0gJiYgZWNobyAiaXAgYWRkcmVzcyBvZiBicmlkZ2UgZGV2aWNlICckQlJJ
REdFX0lGTkFNRSc6ICRJUF9BRERSIiAmJiBleGl0IDAKICAgICAgICBzbGVlcCA1CiAgICBkb25l
CiAgICBlY2hvICJGYWlsIHRvIGdldCBpcCBhZGRyZXNzIG9mIGJyaWRnZSBkZXZpY2UgJyRCUklE
R0VfSUZOQU1FJyBpbiAyIG1pbnMiCiAgICBleGl0IDEKfQoKQlJJREdFX0lGTkFNRT0nc3dpdGNo
JwoKX3NldHVwX2JyaWRnZQpfY2hrX2JyaWRnZV9kZXZfaXAK
EOF
chmod a+rx /root/setup_bridge.sh

## Adding qemu-ifup/down scripts to help manually debugging
base64 -d <<EOF > /etc/qemu-ifup
IyEvYmluL3NoCnN3aXRjaD1zd2l0Y2gKL3Vzci9zYmluL2lwIGxpbmsgc2V0ICQxIHVwCi91c3Iv
c2Jpbi9pcCBsaW5rIHNldCBkZXYgJDEgbWFzdGVyICR7c3dpdGNofQovdXNyL3NiaW4vaXAgbGlu
ayBzZXQgJHtzd2l0Y2h9IHR5cGUgYnJpZGdlIGZvcndhcmRfZGVsYXkgMAovdXNyL3NiaW4vaXAg
bGluayBzZXQgJHtzd2l0Y2h9IHR5cGUgYnJpZGdlIHN0cF9zdGF0ZSAwCg==
EOF

base64 -d <<EOF > /etc/qemu-ifdown
IyEvYmluL3NoCnN3aXRjaD1zd2l0Y2gKL3Vzci9zYmluL2lwIGxpbmsgc2V0ICQxIGRvd24KL3Vz
ci9zYmluL2lwIGxpbmsgc2V0IGRldiAkMSBub21hc3Rlcgo=
EOF
chmod a+rx /etc/qemu-if*
## End adding qemu-ifup/down scripts

## Install brewkoji
curl -kL 'http://download.eng.bos.redhat.com/rel-eng/internal/rcm-tools-rhel-8-baseos.repo' -o /etc/yum.repos.d/rcm-tools-rhel-8.repo
dnf install brewkoji -y
## End brewkoji installation

## Generate 'component_management.py'
base64 -d <<EOF > /root/component_management.py
aW1wb3J0IGFyZ3BhcnNlCmltcG9ydCBqc29uCmltcG9ydCBvcwppbXBvcnQgcGxhdGZvcm0KaW1w
b3J0IHJlCmltcG9ydCByZXF1ZXN0cwppbXBvcnQgc2h1dGlsCmltcG9ydCBzdWJwcm9jZXNzCmlt
cG9ydCBzeXMKCgojIEdsb2JhbCB2YXJpYWJsZXMKUk9PVF9ESVIgPSBvcy5wYXRoLmFic3BhdGgo
b3MucGF0aC5kaXJuYW1lKF9fZmlsZV9fKSkKUVVJRVQgPSBGYWxzZQpET1dOR1JBREUgPSBGYWxz
ZQpMT0dfTFZMID0gMQpQS0dfTUdNVF9CSU4gPSAieXVtIgpCUkVXX1VSTCA9ICJodHRwOi8vZG93
bmxvYWQuZGV2ZWwucmVkaGF0LmNvbSIKTUJTX1VSTCA9ICJodHRwczovL21icy5lbmdpbmVlcmlu
Zy5yZWRoYXQuY29tL21vZHVsZS1idWlsZC1zZXJ2aWNlLzEvbW9kdWxlLWJ1aWxkcyIKUFlUSE9O
X01PRFVMRV9MSVNUID0gInB5dGhvbjItcHl5YW1sIgoKCiMgQSBjb2xsZWN0aW9uIG9mIFB5dGhv
biB1dGlsaXRpZXMgZnVuY3Rpb25zCmRlZiBfbG9nKGx2bCwgbXNnKToKICAgICIiIlByaW50IGEg
bWVzc2FnZSB3aXRoIGxldmVsICdsdmwnIHRvIENvbnNvbGUiIiIKICAgIGlmIG5vdCBRVUlFVCBh
bmQgbHZsIDw9IExPR19MVkw6CiAgICAgICAgcHJpbnQobXNnKQoKZGVmIF9sb2dfZGVidWcobXNn
KToKICAgICIiIlByaW50IGEgbWVzc2FnZSB3aXRoIGxldmVsIERFQlVHIHRvIENvbnNvbGUiIiIK
ICAgIG1zZyA9ICJcMDMzWzk2bURFQlVHOiAiICsgbXNnICsgIlwwMzNbMDBtIgogICAgX2xvZyg0
LCBtc2cpCgpkZWYgX2xvZ19pbmZvKG1zZyk6CiAgICAiIiJQcmludCBhIG1lc3NhZ2Ugd2l0aCBs
ZXZlbCBJTkZPIHRvIENvbnNvbGUiIiIKICAgIG1zZyA9ICJcMDMzWzkybUlORk86ICIgKyBtc2cg
KyAiXDAzM1swMG0iCiAgICBfbG9nKDMsIG1zZykKCmRlZiBfbG9nX3dhcm4obXNnKToKICAgICIi
IlByaW50IGEgbWVzc2FnZSB3aXRoIGxldmVsIFdBUk4gdG8gQ29uc29sZSIiIgogICAgbXNnID0g
IlwwMzNbOTNtV0FSTjogIiArIG1zZyArICJcMDMzWzAwbSIKICAgIF9sb2coMiwgbXNnKQoKZGVm
IF9sb2dfZXJyb3IobXNnKToKICAgICIiIlByaW50IGEgbWVzc2FnZSB3aXRoIGxldmVsIEVSUk9S
IHRvIENvbnNvbGUiIiIKICAgIG1zZyA9ICJcMDMzWzkxbUVSUk9SOiAiICsgbXNnICsgIlwwMzNb
MDBtIgogICAgX2xvZygxLCBtc2cpCgpkZWYgX3N5c3RlbV9zdGF0dXNfb3V0cHV0KGNtZCk6CiAg
ICAiIiJSdW4gYSBzdWJwcm9jZXNzLCByZXR1cm5pbmcgaXRzIGV4aXQgY29kZSBhbmQgb3V0cHV0
LiIiIgogICAgc3AgPSBzdWJwcm9jZXNzLlBvcGVuKGNtZCwgc3Rkb3V0PXN1YnByb2Nlc3MuUElQ
RSwKICAgICAgICAgICAgICAgICAgICAgICAgICBzdGRlcnI9c3VicHJvY2Vzcy5QSVBFLCBzaGVs
bD1UcnVlKQogICAgc3Rkb3V0LCBzdGRlcnIgPSBzcC5jb21tdW5pY2F0ZSgpCiAgICAjIyBXYWl0
IGZvciBjb21tYW5kIHRvIHRlcm1pbmF0ZS4gR2V0IHJldHVybiByZXR1cm5jb2RlICMjCiAgICBz
dGF0dXMgPSBzcC53YWl0KCkKICAgIHJldHVybiAoc3RhdHVzLCBzdGRvdXQuZGVjb2RlKCksIHN0
ZGVyci5kZWNvZGUoKSkKCmRlZiBfc3lzdGVtKGNtZCk6CiAgICAiIiJSdW4gYSBzdWJwcm9jZXNz
LCByZXR1cm5pbmcgaXRzIGV4aXQgY29kZS4iIiIKICAgIHJldHVybiBfc3lzdGVtX3N0YXR1c19v
dXRwdXQoY21kKVswXQoKZGVmIF9zeXN0ZW1fb3V0cHV0KGNtZCk6CiAgICAiIiJSdW4gYSBzdWJw
cm9jZXNzLCByZXR1cm5pbmcgaXRzIG91dHB1dC4iIiIKICAgIHJldHVybiBfc3lzdGVtX3N0YXR1
c19vdXRwdXQoY21kKVsxXQoKZGVmIF9ydW5fY21kKGNtZCk6CiAgICAiIiIKICAgIFJ1biBhIHN1
YnByb2Nlc3MsIHJldHVybmluZyBpdHMgZXhpdCBjb2RlIGFuZCBwcmludCBzdGRvdXQvc3RkZXJy
CiAgICB0byBDb25zb2xlLgogICAgIiIiCiAgICBpZiBRVUlFVCBvciBMT0dfTFZMIDw9IDE6CiAg
ICAgICAgcmV0dXJuIF9zeXN0ZW1fc3RhdHVzX291dHB1dChjbWQpWzBdCiAgICBlbHNlOgogICAg
ICAgIG1zZyA9ICJcMDMzWzFtPT4gJXNcMDMzWzBtIiAlIGNtZAogICAgICAgIF9sb2coTE9HX0xW
TCwgbXNnKQogICAgICAgIHNwID0gc3VicHJvY2Vzcy5Qb3BlbihjbWQsIHNoZWxsPVRydWUpCiAg
ICAgICAgcmV0dXJuIHNwLndhaXQoKQoKZGVmIF9leGl0KHJldCk6CiAgICAiIiJFeGl0IGZyb20g
cHl0aG9uIGFjY29yZGluZyB0byB0aGUgZ2l2aW5nIGV4aXQgY29kZSIiIgogICAgaWYgcmV0ICE9
IDA6CiAgICAgICAgX2xvZyhMT0dfTFZMLCAiUGxlYXNlIGhhbmRsZSB0aGUgRVJST1IocykgYW5k
IHJlLXJ1biB0aGlzIHNjcmlwdCIpCiAgICBzeXMuZXhpdChyZXQpCgpkZWYgX2V4aXRfb25fZXJy
b3IocmV0LCBtc2cpOgogICAgIiIiUHJpbnQgdGhlIGVycm9yIG1lc3NhZ2UgYW5kIGV4aXQgZnJv
bSBweXRob24gd2hlbiBsYXN0IGNvbW1hbmQgZmFpbHMiIiIKICAgIGlmIHJldCAhPSAwOgogICAg
ICAgIF9sb2dfZXJyb3IobXNnKQogICAgICAgIF9leGl0KDEpCgpkZWYgX3dhcm5fb25fZXJyb3Io
cmV0LCBtc2cpOgogICAgIiIiUHJpbnQgdGhlIHdhcm4gbWVzc2FnZSB3aGVuIGxhc3QgY29tbWFu
ZCBmYWlscyIiIgogICAgaWYgcmV0ICE9IDA6CiAgICAgICAgX2xvZ193YXJuKG1zZykKICAgIApk
ZWYgX2hhc19jbWQoY21kKToKICAgICIiIkNoZWNrIHdoZXRoZXIgYSBwcm9ncmFtIGlzIGluc3Rh
bGxlZCIiIgogICAgcmV0dXJuIF9zeXN0ZW0oImNvbW1hbmQgLXYgJXMiICUgY21kKSA9PSAwCgpk
ZWYgX2hhc19ycG0ocGtnKToKICAgICIiIkNoZWNrIHdoZXRoZXIgYSBwYWNrYWdlIGlzIGluc3Rh
bGxlZCIiIgogICAgcmV0dXJuIF9zeXN0ZW0oInJwbSAtcSAlcyIgJSBwa2cpCgpkZWYgX2hhc19t
b2Rfc3BlYyhtb2Rfc3BlYyk6CiAgICAiIiJDaGVjayB3aGV0aGVyIGEgbW9kdWxlIG9yIG1vZHVs
ZSBzdHJlYW0gY291bGQgYmUgdXNlZCIiIgogICAgcmV0dXJuIF9zeXN0ZW0oIiVzIG1vZHVsZSBp
bmZvICVzIiAlIChQS0dfTUdNVF9CSU4sIG1vZF9zcGVjKSkKCmRlZiBfY2hrX21vZF9lbmFibGVk
KG1vZF9zcGVjKToKICAgICIiIkNoZWNrIHdoZXRoZXIgYSBtb2R1bGUgb3IgbW9kdWxlIHN0cmVh
bSBpcyBlbmFibGVkIiIiCiAgICByZXR1cm4gX3N5c3RlbSgiJXMgbW9kdWxlIGxpc3QgLS1lbmFi
bGVkICVzIiAlIChQS0dfTUdNVF9CSU4sIG1vZF9zcGVjKSkKCmRlZiBfY2hrX21vZF9kaXNhYmxl
ZChtb2Rfc3BlYyk6CiAgICAiIiJDaGVjayB3aGV0aGVyIGEgbW9kdWxlIG9yIG1vZHVsZSBzdHJl
YW0gaXMgZGlzYWJsZWQiIiIKICAgIHJldHVybiBfc3lzdGVtKCIlcyBtb2R1bGUgbGlzdCAtLWRp
c2FibGVkICVzIiAlIChQS0dfTUdNVF9CSU4sIG1vZF9zcGVjKSkKCmRlZiBfY2hrX21vZF9pbnN0
YWxsZWQobW9kX3NwZWMpOgogICAgIiIiQ2hlY2sgd2hldGhlciBhIG1vZHVsZSBvciBtb2R1bGUg
c3RyZWFtIGlzIGluc3RhbGxlZCIiIgogICAgcmV0dXJuIF9zeXN0ZW0oIiVzIG1vZHVsZSBsaXN0
IC0taW5zdGFsbGVkICVzIiAlIChQS0dfTUdNVF9CSU4sIG1vZF9zcGVjKSkKCmRlZiBfcGFyc2Vf
YnJld19wa2coYnJld19wa2cpOgogICAgIiIiCiAgICBQYXJzZSB0aGUgYXJndW1lbnQgdG8gZ2V0
IGluZm9ybWF0aW9uIG9mIGJyZXcgcGFja2FnZS4KICAgIDogcmV0dXJuIGJ1aWxkOiAgQnVpbGQg
bmFtZSBleHBlY3RlZCB0byBiZSBpbnN0YWxsZWQKICAgIDogcmV0dXJuIHBrZ3M6ICAgUlBNcyBs
aXN0IGluY2x1ZGVkIGluIHRoZSBidWlsZCB3aGljaCBhcmUgZXhwZWN0ZWQgdG8gYmUKICAgICAg
ICAgICAgICAgICAgICAgaW5zdGFsbGVkLiBJZiBOb25lLCBhbGwgdGhlIFJQTXMgaW5jbHVkZWQg
aW4gdGhlIGJ1aWxkCiAgICAgICAgICAgICAgICAgICAgIHdpbGwgYmUgaW5zdGFsbGVkCiAgICA6
IHJldHVybiBhcmNoZXM6IEFyY2hpdGVjdHVyZSBzcGVjaWZpZWQgUlBNcyB3aWxsIGJlIGluc3Rh
bGxlZC4gSWYgTm9uZSwKICAgICAgICAgICAgICAgICAgICAgdGhlIGRlZmF1bHQgdmFsdWUgYXJl
IHRoZSBob3N0IG1hY2hpbmUgdHlwZSBhbmQgbm9hcmNoCiAgICAiIiIKICAgIGJ1aWxkID0gYnJl
d19wa2cuc3BsaXQoJy8nKVswXQogICAgdGFnID0gJycKICAgIHBrZ3MgPSAnJwogICAgYXJjaGVz
ID0gcGxhdGZvcm0ubWFjaGluZSgpCiAgICBpZiBidWlsZC5maW5kKCJAIikgPj0gMDoKICAgICAg
ICB0YWcgPSBidWlsZC5zcGxpdCgnQCcpWzFdCiAgICAgICAgYnVpbGQgPSBidWlsZC5zcGxpdCgn
QCcpWzBdCiAgICAgICAgY21kID0gImJyZXcgbGF0ZXN0LWJ1aWxkICVzICVzIC0tcXVpZXQgMj4m
MSIgJSAodGFnLCBidWlsZCkKICAgICAgICAocmV0LCBvdXQsIF8pID0gX3N5c3RlbV9zdGF0dXNf
b3V0cHV0KGNtZCkKICAgICAgICBfZXhpdF9vbl9lcnJvcihyZXQsICJGYWlsZWQgdG8gZ2V0IHRo
ZSBsYXRlc3QgYnVpbGQgb2YgJyVzICglcyknLCIKICAgICAgICAgICAgICAgICAgICAgICAiIGNv
bW1hbmQgb3V0cHV0OlxuJXMiICUgKGJ1aWxkLCB0YWcsIG91dCkpCiAgICAgICAgYnVpbGQgPSBv
dXQuc3BsaXQoKVswXQogICAgaWYgYnJld19wa2cuY291bnQoIi8iKSA+PSAxOgogICAgICAgIHBr
Z3MgPSBicmV3X3BrZy5zcGxpdCgnLycpWzFdCiAgICBpZiBicmV3X3BrZy5jb3VudCgiLyIpID09
IDI6CiAgICAgICAgYXJjaGVzID0gYnJld19wa2cuc3BsaXQoJy8nKVsyXQogICAgYXJjaGVzICs9
ICIsbm9hcmNoIgogICAgcmV0dXJuIChidWlsZCwgcGtncywgYXJjaGVzKQoKZGVmIF9nZXRfcnBt
X2xpc3QoYnVpbGQsIGFyY2hlcyk6CiAgICAiIiIKICAgIEdldCBSUE1zIGxpc3QgYWNjb3JkaW5n
IHRvIGJ1aWxkIG5hbWUgYW5kIHNwZWNpZmllZCBhcmNoaXRlY2h0dXJlcy4KICAgICIiIgogICAg
cnBtX2xpc3QgPSBbXQogICAgKHJldCwgb3V0LCBfKSA9IF9zeXN0ZW1fc3RhdHVzX291dHB1dCgi
YnJldyBidWlsZGluZm8gJXMgMj4mMSIgJSBidWlsZCkKICAgIF9leGl0X29uX2Vycm9yKHJldCwg
IkZhaWxlZCB0byBnZXQgYnVpbGQgaW5mb21hdGlvbiBvZiAnJXMnLCBjb21tYW5kIgogICAgICAg
ICAgICAgICAgICAgIiBvdXRwdXQ6XG4lcyIgJSAoYnVpbGQsIG91dCkpCiAgICBycG1zID0gcmUu
c2VhcmNoKHIiUlBNc1xzKjpccyooW146XSopIiwgb3V0LCByZS5JKS5ncm91cCgxKQogICAgZm9y
IHJwbSBpbiBycG1zLnNwbGl0bGluZXMoKToKICAgICAgICBmb3IgYXJjaCBpbiBhcmNoZXMuc3Bs
aXQoJywnKToKICAgICAgICAgICAgaWYgcnBtLmZpbmQoIiVzLnJwbSIgJSBhcmNoKSA+PSAwOgog
ICAgICAgICAgICAgICAgcnBtX2xpc3QuYXBwZW5kKHJwbS5yZXBsYWNlKCIvbW50L3JlZGhhdCIs
IEJSRVdfVVJMKSkKICAgIHJldHVybiBycG1fbGlzdAoKZGVmIF9nZXRfcmVxdWlyZWRfcnBtX2xp
c3QocnBtX2xpc3QsIHBrZ3MpOgogICAgIiIiCiAgICBHZXQgcmVxdWlyZWQgUlBNcyBmcm9tIHRo
ZSBSUE1zIGxpc3QuIElmIG5vIHNwZWNpZmljIFJQTXMgYXJlIHNwZWNpZmllZCwKICAgIGFsbCB0
aGUgUlBNcyBpbiB0aGUgbGlzdCB3aWxsIGJlIGV4cGVjdGVkIHRvIGJlIGluc3RhbGxlZC4KICAg
ICIiIgogICAgcmVxX3JwbV9saXN0ID0gW10KICAgIGlmIG5vdCBwa2dzOgogICAgICAgIHJldHVy
biBycG1fbGlzdAogICAgZm9yIHBrZyBpbiBwa2dzLnNwbGl0KCcsJyk6CiAgICAgICAgaGFzX3Br
ZyA9IEZhbHNlCiAgICAgICAgZm9yIHJwbSBpbiBycG1fbGlzdDoKICAgICAgICAgICAgaWYgcnBt
LmZpbmQoJy8nKSA+PSAwOgogICAgICAgICAgICAgICAgcGtnX25hbWUgPSBycG0ucnNwbGl0KCcv
JywgMSlbMV0ucnNwbGl0KCctJywgMilbMF0KICAgICAgICAgICAgZWxzZToKICAgICAgICAgICAg
ICAgIHBrZ19uYW1lID0gcnBtLnJzcGxpdCgnLScsIDIpWzBdCiAgICAgICAgICAgIGlmIHBrZ19u
YW1lID09IHBrZzoKICAgICAgICAgICAgICAgIGhhc19wa2cgPSBUcnVlCiAgICAgICAgICAgICAg
ICByZXFfcnBtX2xpc3QuYXBwZW5kKHJwbSkKICAgICAgICBpZiBub3QgaGFzX3BrZzoKICAgICAg
ICAgICAgX2xvZ19pbmZvKCInJXMnIGlzIG5vdCBpbiAnJXMnLCBza2lwcGVkIiAlIChwa2csIHJw
bV9saXN0KSkKICAgIHJldHVybiByZXFfcnBtX2xpc3QgaWYgcmVxX3JwbV9saXN0IGVsc2UgcnBt
X2xpc3QKCmRlZiBfZ2V0X21vZF9pbmZvX2Zyb21fbWJzKG1vZF9pZCk6CiAgICAiIiIKICAgIEdl
dCBtb2R1bGUgaW5mb3JtYXRpb24gYWNjb3JkaW5nIHRvIHRoZSBtb2R1bGUgaWQgZnJvbSBNQlMu
CiAgICAiIiIKICAgIG1vZF9pbmZvID0ge30KICAgIHVybCA9IE1CU19VUkwgKyAnLycgKyBtb2Rf
aWQKICAgIHJlc3BvbnNlID0ganNvbi5sb2FkcyhyZXF1ZXN0cy5nZXQodXJsKS50ZXh0KQogICAg
bW9kX2luZm9bJ3N0YXRlX25hbWUnXSA9IHJlc3BvbnNlLmdldCgic3RhdGVfbmFtZSIpCiAgICBt
b2RfaW5mb1snc2NtdXJsJ10gPSByZXNwb25zZS5nZXQoInNjbXVybCIpCiAgICBtb2RfaW5mb1sn
a29qaV90YWcnXSA9IHJlc3BvbnNlLmdldCgia29qaV90YWciKQogICAgbW9kX2luZm9bJ3JwbXMn
XSA9IHJlc3BvbnNlLmdldCgidGFza3MiKS5nZXQoInJwbXMiKQogICAgcmV0dXJuIG1vZF9pbmZv
CgpkZWYgX2NoZWNrX21vZHVsZV9pc19yZWFkeShtb2RfaWQpOgogICAgIiIiCiAgICBDaGVjayB3
aGV0aGVyIHRoZSBtb2R1bGUgc3RhdGUgaXMgcmVhZHkuIFdoZW4gdGhlIHN0YXRlIGlzIEZhaWxl
ZCwgbW9kdWxlCiAgICBzaG91bGQgbm90IGJlIHVzZWQgZm9yIHRlc3RpbmcuCiAgICAiIiIKICAg
IG1vZF9pbmZvID0gX2dldF9tb2RfaW5mb19mcm9tX21icyhtb2RfaWQpCiAgICBpZiBtb2RfaW5m
by5nZXQoJ3N0YXRlX25hbWUnKSA9PSAicmVhZHkiOgogICAgICAgIHJldHVybiBUcnVlCiAgICBy
ZXR1cm4gRmFsc2UKCmRlZiBfZ2V0X21vZF9pZF9mcm9tX2tvamlfdGFnKGtvamlfdGFnKToKICAg
ICIiIgogICAgVXNlIHRoZSBrb2ppIHRhZyB0byBnZXQgYWxsIHRoZSBjb21wb25lbnRzIGluY2x1
ZGVkIGluIHRoZSBtb2R1bGUsIGFuZCB0aGVuCiAgICBjb21wYXJlIHRoZSBtb2R1bGUgaWQgaW4g
ZWFjaCBjb21wb25lbnQuIFRoZSBtYXhpbXVtIG1vZHVsZSBpZCBzaG91bGQgYmUKICAgIHRoZSBs
YXRlc3Qgb25lLgogICAgIiIiCiAgICBtb2RfaWQgPSBOb25lCiAgICAocmV0LCBjcG50X2xpc3Qs
IF8pID0gX3N5c3RlbV9zdGF0dXNfb3V0cHV0KCJicmV3IGxpc3QtdGFnZ2VkICVzIDI+JjEiICUK
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIGtvamlfdGFn
KQogICAgX2V4aXRfb25fZXJyb3IocmV0LCAiRmFpbGVkIHRvIGdldCBjb21wb25lbmV0IGxpc3Qg
JyVzJywgY29tbWFuZCIKICAgICAgICAgICAgICAgICAgICIgb3V0cHV0OlxuJXMiICUgKGtvamlf
dGFnLCBjcG50X2xpc3QpKQogICAgZm9yIGNwbnQgaW4gY3BudF9saXN0LnNwbGl0bGluZXMoKToK
ICAgICAgICBzZWFyY2hfb2JqID0gcmUuc2VhcmNoKHIibW9kdWxlXCtlbFteK10rXCsoXGQrKVwr
IiwgY3BudCwgcmUuSSkKICAgICAgICBpZiBub3Qgc2VhcmNoX29iajoKICAgICAgICAgICAgY29u
dGludWUKICAgICAgICBpZiBub3QgbW9kX2lkIG9yIG1vZF9pZCA8IHNlYXJjaF9vYmouZ3JvdXAo
MSk6CiAgICAgICAgICAgIG1vZF9pZCA9IHNlYXJjaF9vYmouZ3JvdXAoMSkKICAgIHJldHVybiBt
b2RfaWQKCmRlZiBfZG93bmdyYWRlX21vZHVsZV92ZXJzaW9uKG5hbWUsIHN0cmVhbSwgcmVsZWFz
ZSk6CiAgICAiIiIKICAgIGRvd25ncmFkZSBtb2R1bGUgdmVyc2lvbiB3aGVuIHRoZXJlIGlzIG5v
IGF2YWlsYWJsZSBtb2R1bGUgZm9yIGN1cnJlbnQgcmVsZWFzZQogICAgIiIiCiAgICBmaXJzdFZl
cnNpb24gPSByZWxlYXNlLnNwbGl0KCcuJylbMF0KICAgIHNlY29uZFZlcnNpb24gPSBpbnQocmVs
ZWFzZS5zcGxpdCgnLicpWzFdKQogICAgdGhpcmRWZXJzaW9uID0gaW50KHJlbGVhc2Uuc3BsaXQo
Jy4nKVsyXSkKICAgIGlmIHN0cmVhbSA9PSAicmhlbCI6CiAgICAgICAgc2Vjb25kVmVyc2lvbiA9
IHNlY29uZFZlcnNpb24gLSAxCiAgICAgICAgcmV0dXJuICIlczolczolcy4lcy4lcyIgJSAobmFt
ZSwgc3RyZWFtLCBmaXJzdFZlcnNpb24sIHNlY29uZFZlcnNpb24sIHRoaXJkVmVyc2lvbikKICAg
IGlmIHRoaXJkVmVyc2lvbiA+IDA6CiAgICAgICAgdGhpcmRWZXJzaW9uID0gdGhpcmRWZXJzaW9u
IC0xCiAgICBlbHNlOgogICAgICAgIHNlY29uZFZlcnNpb24gPSBzZWNvbmRWZXJzaW9uIC0xCiAg
ICAgICAgc3RyZWFtID0gIiVzLiVzIiAlIChmaXJzdFZlcnNpb24sIHNlY29uZFZlcnNpb24pCiAg
ICByZXR1cm4gIiVzOiVzOiVzLiVzLiVzIiAlIChuYW1lLCBzdHJlYW0sIGZpcnN0VmVyc2lvbiwg
c2Vjb25kVmVyc2lvbiwgdGhpcmRWZXJzaW9uKQoKZGVmIF9nZXRfbW9kX2lkX2Zyb21fbW9kdWxl
KG1vZF9uYW1lKToKICAgICIiIgogICAgR2V0IGtvamkgdGFnIGZyb20gbW9kdWxlIG5hbWUgYW5k
IG1vZHVsZSBzdHJlYW0sIHRoZW4gdXNlIGtvamkgdGFnIHRvIGdldAogICAgdGhlIG1vZHVsZSBp
ZC4KICAgICIiIgogICAgaWYgbGVuKG1vZF9uYW1lLnNwbGl0KCc6JykpICE9IDM6CiAgICAgICAg
X2V4aXRfb25fZXJyb3IoMSwgIkludmFsaWQgbW9kdWxlIG5hbWU6ICVzIiAlIG1vZF9uYW1lKQog
ICAgbmFtZSA9IG1vZF9uYW1lLnNwbGl0KCc6JylbMF0KICAgIHN0cmVhbSA9IG1vZF9uYW1lLnNw
bGl0KCc6JylbMV0KICAgIHRhcmdldF9yZWxlYXNlID0gbW9kX25hbWUuc3BsaXQoJzonKVsyXQog
ICAgaWYgbGVuKHRhcmdldF9yZWxlYXNlLnNwbGl0KCcuJykpICE9IDM6CiAgICAgICAgX2V4aXRf
b25fZXJyb3IoMSwgIkludmFsaWQgdGFyZ2V0IHJlbGVhc2U6ICVzIiAlIHRhcmdldF9yZWxlYXNl
KQogICAgdmVyc2lvbiA9IHRhcmdldF9yZWxlYXNlLnNwbGl0KCcuJylbMF0KICAgIGZvciBpIGlu
IHJhbmdlKDEsMyk6CiAgICAgICAgdiA9IHRhcmdldF9yZWxlYXNlLnNwbGl0KCcuJylbaV0KICAg
ICAgICBpZiBsZW4odikgPT0gMjoKICAgICAgICAgICAgdmVyc2lvbiA9IHZlcnNpb24gKyB2CiAg
ICAgICAgZWxpZiBsZW4odikgPT0gMToKICAgICAgICAgICAgdmVyc2lvbiA9IHZlcnNpb24gKyAn
MCcgKyB2CiAgICAgICAgZWxzZToKICAgICAgICAgICAgX2V4aXRfb25fZXJyb3IoMSwgIkludmFs
aWQgdGFyZ2V0IHJlbGVhc2U6ICVzIiAlIHRhcmdldF9yZWxlYXNlKQogICAgcGxhdGZvcm1fdGFn
ID0gIm1vZHVsZS0lcy0lcy0lcyIgJSAobmFtZSwgc3RyZWFtLCB2ZXJzaW9uKQogICAgY21kID0g
ImJyZXcgbGlzdC10YXJnZXRzIHwgZ3JlcCAlcyB8IHNvcnQgLXIgMj4mMSIgJSBwbGF0Zm9ybV90
YWcKICAgIChyZXQsIGtvamlfdGFnX2xpc3QsIF8pID0gX3N5c3RlbV9zdGF0dXNfb3V0cHV0KGNt
ZCkKICAgIF9leGl0X29uX2Vycm9yKHJldCwgIkZhaWxlZCB0byBnZXQga29qaSB0YWcgb2YgJyVz
JywgY29tbWFuZCIKICAgICAgICAgICAgICAgICAgICIgb3V0cHV0OlxuJXMiICUgKHBsYXRmb3Jt
X3RhZywga29qaV90YWdfbGlzdCkpCiAgICBmb3Iga29qaV90YWcgaW4ga29qaV90YWdfbGlzdC5z
cGxpdGxpbmVzKCk6CiAgICAgICAgbW9kX2lkID0gX2dldF9tb2RfaWRfZnJvbV9rb2ppX3RhZyhr
b2ppX3RhZy5zcGxpdCgpWzBdKQogICAgICAgIGlmIF9jaGVja19tb2R1bGVfaXNfcmVhZHkobW9k
X2lkKToKICAgICAgICAgICAgcmV0dXJuIG1vZF9pZAogICAgaWYgRE9XTkdSQURFOgogICAgICAg
IG5ld19tb2RfbmFtZSA9IF9kb3duZ3JhZGVfbW9kdWxlX3ZlcnNpb24obmFtZSwgc3RyZWFtLCB0
YXJnZXRfcmVsZWFzZSkKICAgICAgICByZXR1cm4gX2dldF9tb2RfaWRfZnJvbV9tb2R1bGUobmV3
X21vZF9uYW1lKQogICAgcmV0dXJuIE5vbmUKCmRlZiBfZ2V0X21vZF9pZF9mcm9tX3BhY2thZ2Uo
cGtnX25hbWUpOgogICAgIiIiCiAgICBHZXQga29qaSB0YWcgZnJvbSBwYWNrYWdlIG5hbWUuIFRo
ZW4gZ2V0IHRoZSBtb2R1bGUgaWQgZnJvbSBrb2ppIHRhZy4KICAgIE5vdGljZSB0aGF0IG5vdCBh
bGwgdGhlIGdvdHRlbiBrb2ppIHRhZ3MgY291bGQgYmUgdXNlZC4gU29tZSBvZiB0aGVtIG1heQog
ICAgYmUgYmVsb25nZWQgdG8gYSBhYm9ydGVkIG1vZHVsZS4KICAgICIiIgogICAgaWYgcGtnX25h
bWUuc3RhcnRzd2l0aCgibW9kdWxlLXZpcnQiKToKICAgICAgICB0YWdzID0gcGtnX25hbWUKICAg
IGVsc2U6CiAgICAgICAgKHJldCwgb3V0LCBfKSA9IF9zeXN0ZW1fc3RhdHVzX291dHB1dCgiYnJl
dyBidWlsZGluZm8gJXMgMj4mMSIgJQogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgcGtnX25hbWUpCiAgICAgICAgX2V4aXRfb25fZXJyb3IocmV0LCAiRmFpbGVk
IHRvIGdldCBidWlsZCBpbmZvbWF0aW9uIG9mICclcycsIGNvbW1hbmQiCiAgICAgICAgICAgICAg
ICAgICAgICAgIiBvdXRwdXQ6XG4lcyIgJSAocGtnX25hbWUsIG91dCkpCiAgICAgICAgdGFncyA9
IHJlLnNlYXJjaChyIlRhZ3Nccyo6XHMqKC4qKSIsIG91dCwgcmUuSSkuZ3JvdXAoMSkKICAgIHRh
Z19saXN0ID0gdGFncy5zcGxpdCgpCiAgICB0YWdfbGlzdC5yZXZlcnNlKCkKICAgIGZvciBrb2pp
X3RhZyBpbiB0YWdfbGlzdDoKICAgICAgICBpZiBrb2ppX3RhZy5lbmRzd2l0aCgiLWJ1aWxkIik6
CiAgICAgICAgICAgIGNvbnRpbnVlCiAgICAgICAgbW9kX2lkID0gX2dldF9tb2RfaWRfZnJvbV9r
b2ppX3RhZyhrb2ppX3RhZykKICAgICAgICBpZiBfY2hlY2tfbW9kdWxlX2lzX3JlYWR5KG1vZF9p
ZCk6CiAgICAgICAgICAgIHJldHVybiBtb2RfaWQKICAgIHJldHVybiBOb25lCgpkZWYgX2dldF9t
b2RfaWQobW9kX2lkKToKICAgICIiIgogICAgR2V0IG1vZHVsZSBpZAogICAgIiIiCiAgICBpZiBt
b2RfaWQuaXNkaWdpdCgpOgogICAgICAgIHJldHVybiBtb2RfaWQKICAgIGlmIG1vZF9pZC5zdGFy
dHN3aXRoKCd2aXJ0OicpOgogICAgICAgIHJldHVybiBfZ2V0X21vZF9pZF9mcm9tX21vZHVsZSht
b2RfaWQpCiAgICByZXR1cm4gX2dldF9tb2RfaWRfZnJvbV9wYWNrYWdlKG1vZF9pZCkKCmRlZiBf
Z2V0X3JwbV9saXN0X2Zyb21fdmlydF95YW1sKG1vZF9pbmZvKToKICAgICIiIgogICAgR2V0IFJQ
TXMgbGlzdCBmb3IgdmlydCBtb2R1bGUgZnJvbSB0aGUgeWFtbCBjb25maWd1cmF0aW9uLgogICAg
IiIiCiAgICBpbXBvcnQgeWFtbAogICAgcmVwb19kaXIgPSBvcy5wYXRoLmpvaW4oUk9PVF9ESVIs
ICJ2aXJ0IikKICAgIHlhbWxfY29uZiA9IG9zLnBhdGguam9pbihyZXBvX2RpciwgInZpcnQueWFt
bCIpCiAgICByZXBvID0gbW9kX2luZm8uZ2V0KCJzY211cmwiKS5zcGxpdCgnPyMnKVswXQogICAg
Y29tbWl0X2hhc2ggPSBtb2RfaW5mby5nZXQoInNjbXVybCIpLnNwbGl0KCc/IycpWzFdCiAgICBp
ZiBvcy5wYXRoLmV4aXN0cyhyZXBvX2Rpcik6CiAgICAgICAgc2h1dGlsLnJtdHJlZShyZXBvX2Rp
cikKICAgIChyZXQsIF8sIGVycikgPSBfc3lzdGVtX3N0YXR1c19vdXRwdXQoImdpdCBjbG9uZSAl
cyAlcyIgJSAocmVwbywgcmVwb19kaXIpKQogICAgX2V4aXRfb25fZXJyb3IocmV0LCAiRmFpbGVk
IHRvIGNsb25lIHJlcG8gJyVzJywgRXJyb3IgbWVzc2FnZTpcbiVzIiAlCiAgICAgICAgICAgICAg
ICAgICAocmVwbywgZXJyKSkKICAgIF9zeXN0ZW0oImdpdCAtQyAlcyBjaGVja291dCAlcyIgJSAo
cmVwb19kaXIsIGNvbW1pdF9oYXNoKSkKICAgIHZpcnRfaW5mbyA9IHlhbWwubG9hZChvcGVuKHlh
bWxfY29uZikpCiAgICBycG1zX2luZm8gPSB2aXJ0X2luZm8uZ2V0KCJkYXRhIikuZ2V0KCJjb21w
b25lbnRzIikuZ2V0KCJycG1zIikKICAgIHJldHVybiBycG1zX2luZm8KCmRlZiBfZ2V0X2NwbnRf
bGlzdF9mb3JfcWVtdShtb2RfaW5mbyk6CiAgICAiIiIKICAgIEdldCBjb21wb25lbnQgbGlzdCBm
b3IgcWVtdSBhbmQgcWVtdSBkZXBlbmRlbmNpZXMuCiAgICAiIiIKICAgIGNwbnRfbGlzdCA9IFtd
CiAgICBycG1zX2luZm8gPSBfZ2V0X3JwbV9saXN0X2Zyb21fdmlydF95YW1sKG1vZF9pbmZvKQog
ICAgZm9yIHJwbSBpbiBycG1zX2luZm8ua2V5cygpOgogICAgICAgIGlmIHJwbXNfaW5mby5nZXQo
cnBtKS5nZXQoInJhdGlvbmFsZSIpLmZpbmQoInFlbXUta3ZtIikgPCAwOgogICAgICAgICAgICBj
b250aW51ZQogICAgICAgIGlmIG5vdCBycG1zX2luZm8uZ2V0KHJwbSkuZ2V0KCJhcmNoZXMiKToK
ICAgICAgICAgICAgY3BudF9saXN0LmFwcGVuZChycG0pCiAgICAgICAgICAgIGNvbnRpbnVlCiAg
ICAgICAgaWYgcGxhdGZvcm0ubWFjaGluZSgpIGluIHJwbXNfaW5mby5nZXQocnBtKS5nZXQoImFy
Y2hlcyIpOgogICAgICAgICAgICBjcG50X2xpc3QuYXBwZW5kKHJwbSkKICAgIGNwbnRfbGlzdC5h
cHBlbmQoJ3FlbXUta3ZtJykKICAgIHJldHVybiBjcG50X2xpc3QKCmRlZiBfZ2V0X3BrZ19saXN0
X2Zvcl9xZW11KG1vZF9pZCk6CiAgICAiIiIKICAgIEdldCBwYWNrYWdlIGxpc3QgZm9yIHFlbXUg
YW5kIHFlbXUgZGVwZW5kZW5jaWVzLgogICAgIiIiCiAgICBwa2dfbGlzdCA9IFtdCiAgICBtb2Rf
aW5mbyA9IF9nZXRfbW9kX2luZm9fZnJvbV9tYnMobW9kX2lkKQogICAgY3BudF9saXN0ID0gX2dl
dF9jcG50X2xpc3RfZm9yX3FlbXUobW9kX2luZm8pCiAgICBmb3IgY3BudCBpbiBjcG50X2xpc3Q6
CiAgICAgICAgcGtnX2xpc3QuYXBwZW5kKG1vZF9pbmZvLmdldCgicnBtcyIpLmdldChjcG50KS5n
ZXQoIm52ciIpKQogICAgcmV0dXJuIHBrZ19saXN0CgpkZWYgX2luc3RhbGxfcGtnX2xpc3QocGtn
X2xpc3QpOgogICAgIiIiCiAgICBJbnN0YWxsIHJlcXVpcmVkIHBhY2thZ2VzLgogICAgIiIiCiAg
ICAocmV0LCBfLCBlcnIpID0gX3N5c3RlbV9zdGF0dXNfb3V0cHV0KCIlcyBpbnN0YWxsIC15ICVz
IiAlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIChQS0dfTUdNVF9C
SU4sIHBrZ19saXN0KSkKICAgIF9leGl0X29uX2Vycm9yKHJldCwgIkluc3RhbGwgcGFja2FnZXMg
JyVzJyBmYWlsZWQsIGVycm9yIG1lc3NhZ2U6ICVzIiAlCiAgICAgICAgICAgICAgICAgICAocGtn
X2xpc3QsIGVycikpCgoKIyBBIGNvbGxlY3Rpb24gb2YgUHl0aG9uIGJhc2ljIGZ1bmN0aW9ucwpk
ZWYgZW5hYmxlX21vZChtb2Rfc3BlY19saXN0KToKICAgICIiIgogICAgRW5hYmxlIGFsbCB0aGUg
bW9kdWxlIHN0cmVhbXMgaW4gdGhlIG1vZHVsZSBzcGVjIGxpc3QgYW5kIG1ha2UgdGhlIHN0cmVh
bQogICAgUlBNcyBhdmFpbGFibGUgaW4gdGhlIHBhY2thZ2Ugc2V0LgogICAgIiIiCiAgICBpZiBu
b3QgbW9kX3NwZWNfbGlzdDoKICAgICAgICByZXR1cm4KICAgIGZvciBtb2Rfc3BlYyBpbiBtb2Rf
c3BlY19saXN0LnNwbGl0KCk6CiAgICAgICAgX2V4aXRfb25fZXJyb3IoX2hhc19tb2Rfc3BlYyht
b2Rfc3BlYyksCiAgICAgICAgICAgICAgICAgICAgICAgIk1vZHVsZSAnJXMnIGRvZXNuJ3QgZXhp
c3QiICUgbW9kX3NwZWMpCiAgICAgICAgaWYgX2Noa19tb2RfZW5hYmxlZChtb2Rfc3BlYykgPT0g
MDoKICAgICAgICAgICAgY29udGludWUKICAgICAgICBfbG9nX2luZm8oIkVuYWJsZSBNb2R1bGUg
JXMiICUgbW9kX3NwZWMpCiAgICAgICAgKHJldCwgXywgZXJyKSA9IF9zeXN0ZW1fc3RhdHVzX291
dHB1dCgiJXMgbW9kdWxlIGVuYWJsZSAteSAlcyIKICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICUgKFBLR19NR01UX0JJTiwgbW9kX3NwZWMpKQogICAgICAgIGlm
IHJldCAhPSAwOgogICAgICAgICAgICBfZXhpdF9vbl9lcnJvcihfY2hrX21vZF9lbmFibGVkKG1v
ZF9zcGVjKSwKICAgICAgICAgICAgICAgICAgICAgICAgICAgIk1vZHVsZSAnJXMnIHdhc24ndCBl
bmFibGVkKCVzKSIgJSAobW9kX3NwZWMsIGVycikpCgpkZWYgZGlzYWJsZV9tb2QobW9kX3NwZWNf
bGlzdCk6CiAgICAiIiIKICAgIERpc2FibGUgYWxsIHRoZSBtb2R1bGUgaW4gdGhlIG1vZHVsZSBz
cGVjIGxpc3QuIEFsbCByZWxhdGVkIG1vZHVsZSBzdHJlYW1zCiAgICB3aWxsIGJlY29tZSB1bmF2
YWlsYWJsZS4KICAgICIiIgogICAgaWYgbm90IG1vZF9zcGVjX2xpc3Q6CiAgICAgICAgcmV0dXJu
CiAgICBmb3IgbW9kX3NwZWMgaW4gbW9kX3NwZWNfbGlzdC5zcGxpdCgpOgogICAgICAgIF9leGl0
X29uX2Vycm9yKF9oYXNfbW9kX3NwZWMobW9kX3NwZWMpLAogICAgICAgICAgICAgICAgICAgICAg
ICJNb2R1bGUgJyVzJyBkb2Vzbid0IGV4aXN0IiAlIG1vZF9zcGVjKQogICAgICAgIG1vZF9uYW1l
ID0gbW9kX3NwZWMuc3BsaXQoIjoiKVswXQogICAgICAgIGlmIF9jaGtfbW9kX2Rpc2FibGVkKG1v
ZF9uYW1lKSA9PSAwOgogICAgICAgICAgICBjb250aW51ZQogICAgICAgIF9sb2dfaW5mbygiRGlz
YWJsZSBNb2R1bGUgJXMiICUgbW9kX25hbWUpCiAgICAgICAgKHJldCwgXywgZXJyKSA9IF9zeXN0
ZW1fc3RhdHVzX291dHB1dCgiJXMgbW9kdWxlIGRpc2FibGUgLXkgJXMiCiAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAlIChQS0dfTUdNVF9CSU4sIG1vZF9uYW1l
KSkKICAgICAgICBpZiByZXQgIT0wOgogICAgICAgICAgICBfZXhpdF9vbl9lcnJvcihfY2hrX21v
ZF9kaXNhYmxlZChtb2RfbmFtZSksCiAgICAgICAgICAgICAgICAgICAgICAgICAgICJNb2R1bGUg
JyVzJyB3YXNuJ3QgZGlzYWJsZWQoJXMpIiAlCiAgICAgICAgICAgICAgICAgICAgICAgICAgICht
b2RfbmFtZSwgZXJyKSkKCmRlZiBpbnN0YWxsX21vZChtb2Rfc3BlY19saXN0KToKICAgICIiIgog
ICAgSW5zdGFsbCBhbGwgdGhlIG1vZHVsZSBwcm9maWxlcyBpbmNsLiB0aGVpciBSUE1zIGluIHRo
ZSBtb2R1bGUgc3BlYyBsaXN0LgogICAgSW4gY2FzZSBubyBwcm9maWxlIHdhcyBwcm92aWRlZCwg
YWxsIGRlZmF1bHQgcHJvZmlsZXMgZ2V0IGluc3RhbGxlZC4gTW9kdWxlCiAgICBzdHJlYW1zIGdl
dCBlbmFibGVkIGFjY29yZGluZ2x5LgogICAgIiIiCiAgICBpZiBub3QgbW9kX3NwZWNfbGlzdDoK
ICAgICAgICByZXR1cm4KICAgIGZvciBtb2Rfc3BlYyBpbiBtb2Rfc3BlY19saXN0LnNwbGl0KCk6
CiAgICAgICAgX2V4aXRfb25fZXJyb3IoX2hhc19tb2Rfc3BlYyhtb2Rfc3BlYyksCiAgICAgICAg
ICAgICAgICAgICAgICAgIk1vZHVsZSAnJXMnIGRvZXNuJ3QgZXhpc3QiICUgbW9kX3NwZWMpCiAg
ICAgICAgaWYgX2Noa19tb2RfaW5zdGFsbGVkKG1vZF9zcGVjKSA9PSAwOgogICAgICAgICAgICBj
b250aW51ZQogICAgICAgIG1vZF9uYW1lID0gbW9kX3NwZWMuc3BsaXQoIjoiKVswXQogICAgICAg
IGlmIF9jaGtfbW9kX2luc3RhbGxlZChtb2RfbmFtZSkgPT0gMDoKICAgICAgICAgICAgX3N5c3Rl
bSgiJXMgbW9kdWxlIHJlbW92ZSAteSAlcyIgJSAoUEtHX01HTVRfQklOLCBtb2RfbmFtZSkpCiAg
ICAgICAgX2xvZ19pbmZvKCJJbnN0YWxsIE1vZHVsZSAlcyIgJSBtb2Rfc3BlYykKICAgICAgICBv
dXQgPSBfc3lzdGVtX291dHB1dCgiZG5mIG1vZHVsZSBpbmZvICVzIiAlIG1vZF9zcGVjKQogICAg
ICAgIHNlYXJjaF9vYmogPSByZS5zZWFyY2gociJEZWZhdWx0IHByb2ZpbGVzXHMrOlxzKyhcUyop
Iiwgb3V0LCByZS5JKQogICAgICAgIGlmIG5vdCBzZWFyY2hfb2JqOgogICAgICAgICAgICBwcm9m
aWxlID0gcmUuc2VhcmNoKHIiUHJvZmlsZXNccys6XHMrKFxTKikiLAogICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgIG91dCwgcmUuSSkuZ3JvdXAoMSkuc3BsaXQoJywnKVswXQogICAgICAg
ICAgICBtb2Rfc3BlYyA9IG1vZF9zcGVjICsgJy8nICsgcHJvZmlsZQogICAgICAgIChyZXQsIF8s
IGVycikgPSBfc3lzdGVtX3N0YXR1c19vdXRwdXQoIiVzIG1vZHVsZSBpbnN0YWxsIC15ICVzIiAl
CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAoUEtHX01HTVRf
QklOLCBtb2Rfc3BlYykpCiAgICAgICAgaWYgcmV0ICE9IDA6CiAgICAgICAgICAgIF9leGl0X29u
X2Vycm9yKF9jaGtfbW9kX2luc3RhbGxlZChtb2Rfc3BlYy5zcGxpdCgnLycpWzBdKSwKICAgICAg
ICAgICAgICAgICAgICAgICAgICAgIk1vZHVsZSAnJXMnIHdhc24ndCBpbnN0YWxsZWQoJXMpIiAl
CiAgICAgICAgICAgICAgICAgICAgICAgICAgIChtb2Rfc3BlYywgZXJyKSkKCmRlZiBpbnN0YWxs
X3BrZ19mcm9tX3JlcG8ocmVwb19wa2dfbGlzdCk6CiAgICAiIiIKICAgIEluc3RhbGwgYWxsIHRo
ZSBwYWNrYWdlcyBhbmQgdGhlaXIgZGVwZW5kZW5jaWVzIGluIHRoZSBwYWNrYWdlIGxpc3QKICAg
IGZyb20gYW55IGVuYWJsZWQgcmVwb3NpdG9yeS4KICAgICIiIgogICAgaWYgbm90IHJlcG9fcGtn
X2xpc3Q6CiAgICAgICAgcmV0dXJuCiAgICBmb3IgcmVwb19wa2cgaW4gcmVwb19wa2dfbGlzdC5z
cGxpdCgpOgogICAgICAgIGlmIF9oYXNfcnBtKHJlcG9fcGtnKSA9PSAwOgogICAgICAgICAgICBp
ZiBQS0dfTUdNVF9CSU4gPT0gImRuZiI6CiAgICAgICAgICAgICAgICAocmV0LCBfLCBlcnIpID0g
X3N5c3RlbV9zdGF0dXNfb3V0cHV0KCIlcyBkaXN0cm8tc3luYyAteSAlcyIgJQogICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAoUEtHX01HTVRfQklO
LCByZXBvX3BrZykpCiAgICAgICAgICAgICAgICBfZXhpdF9vbl9lcnJvcihyZXQsICJQYWNrYWdl
ICclcycgd2Fzbid0IHN5bmNlZCglcykiICUKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
IChyZXBvX3BrZywgZXJyKSkKICAgICAgICAgICAgY29udGludWUKICAgICAgICBfbG9nX2luZm8o
Ikluc3RhbGwgcGFja2FnZSAlcyIgJSByZXBvX3BrZykKICAgICAgICAocmV0LCBfLCBlcnIpID0g
X3N5c3RlbV9zdGF0dXNfb3V0cHV0KCIlcyBpbnN0YWxsIC15ICVzIiAlCiAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAoUEtHX01HTVRfQklOLCByZXBvX3BrZykp
CiAgICAgICAgaWYgcmV0ICE9IDA6CiAgICAgICAgICAgIF9leGl0X29uX2Vycm9yKF9oYXNfcnBt
KHJlcG9fcGtnKSwKICAgICAgICAgICAgICAgICAgICAgICAgICAgIlBhY2thZ2UgJyVzJyB3YXNu
J3QgaW5zdGFsbGVkKCVzKSIgJQogICAgICAgICAgICAgICAgICAgICAgICAgICAocmVwb19wa2cs
IGVycikpCgpkZWYgaW5zdGFsbF9wa2dfZnJvbV9icmV3KGJyZXdfcGtnX2xpc3QpOgogICAgIiIi
CiAgICBJbnN0YWxsIGFsbCB0aGUgcGFja2FnZXMgYW5kIHRoZWlyIGRlcGVuZGVuY2llcyBpbiB0
aGUgcGFja2FnZSBsaXN0CiAgICBmcm9tIGJyZXcuCiAgICAiIiIKICAgIGlmIG5vdCBicmV3X3Br
Z19saXN0OgogICAgICAgIHJldHVybgogICAgZm9yIGJyZXdfcGtnIGluIGJyZXdfcGtnX2xpc3Qu
c3BsaXQoKToKICAgICAgICAoYnVpbGQsIHBrZ3MsIGFyY2hlcykgPSBfcGFyc2VfYnJld19wa2co
YnJld19wa2cpCiAgICAgICAgcnBtX2xpc3QgPSBfZ2V0X3JwbV9saXN0KGJ1aWxkLCBhcmNoZXMp
CiAgICAgICAgaW5zdGFsbF9ycG1fbGlzdCA9IF9nZXRfcmVxdWlyZWRfcnBtX2xpc3QocnBtX2xp
c3QsIHBrZ3MpCiAgICAgICAgX2xvZ19pbmZvKCJJbnN0YWxsIHBhY2thZ2UgJXMiICUgYnVpbGQp
CiAgICAgICAgKHJldCwgXywgZXJyKSA9IF9zeXN0ZW1fc3RhdHVzX291dHB1dCgiJXMgaW5zdGFs
bCAteSAlcyIgJQogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
KFBLR19NR01UX0JJTiwKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
ICAgICAnICcuam9pbihpbnN0YWxsX3JwbV9saXN0KSkpCiAgICAgICAgaWYgcmV0ICE9IDA6CiAg
ICAgICAgICAgIF9leGl0X29uX2Vycm9yKF9oYXNfcnBtKGJ1aWxkKSwKICAgICAgICAgICAgICAg
ICAgICAgICAgICAgIlBhY2thZ2UgJyVzJyB3YXNuJ3QgaW5zdGFsbGVkKCVzKSIgJQogICAgICAg
ICAgICAgICAgICAgICAgICAgICAoYnVpbGQsIGVycikpCgpkZWYgaW5zdGFsbF92aXJ0X3FlbXVf
ZnJvbV9icmV3KG1vZF9pZCk6CiAgICAiIiIKICAgIEluc3RhbGwgcWVtdSBhbmQgcWVtdSBkZXBl
bmRlbmNpZXMgaW5jbHVkZWQgYSB2aXJ0IG1vZHVsZS4gT3RoZXIgcGFja2FnZXMKICAgIGxpa2Ug
bGlidmlydCB3b3VsZG4ndCBiZSBpbnN0YWxsZWQuIFRoZSBhcmd1bWVudCBjb3VsZCBtb2R1bGUg
aWQsIHFlbXUKICAgIHBhY2thZ2UsIGtvamkgdGFnLCBhbmQgbW9kdWxlIG5hbWUgd2l0aCBzdHJl
YW0uCiAgICAiIiIKICAgIGlmIG5vdCBtb2RfaWQ6CiAgICAgICAgcmV0dXJuCiAgICBtb2RfaWQg
PSBfZ2V0X21vZF9pZChtb2RfaWQpCiAgICBpZiBub3QgbW9kX2lkOgogICAgICAgIF9leGl0X29u
X2Vycm9yKDEsICJGYWlsdCB0byBnZXQgbW9kdWxlIGlkIikKICAgIF9sb2dfaW5mbygiTW9kdWxl
IGlkIGlzICVzIiAlIG1vZF9pZCkKICAgIHBrZ19saXN0ID0gX2dldF9wa2dfbGlzdF9mb3JfcWVt
dShtb2RfaWQpCiAgICBkaXNhYmxlX21vZCgidmlydCIpCiAgICBpbnN0YWxsX3BrZ19mcm9tX2Jy
ZXcoJyAnLmpvaW4ocGtnX2xpc3QpKQoKZGVmIHBhcnNlX29wdHMoKToKICAgICIiIgogICAgUGFy
c2UgYXJndW1lbnRzLgogICAgIiIiCiAgICBwYXJzZXIgPSBhcmdwYXJzZS5Bcmd1bWVudFBhcnNl
cihmb3JtYXR0ZXJfY2xhc3M9YXJncGFyc2UuUmF3VGV4dEhlbHBGb3JtYXR0ZXIpCiAgICBwYXJz
ZXIuYWRkX2FyZ3VtZW50KAogICAgICAgICctLWVuYWJsZS1tb2R1bGUnLAogICAgICAgIGFjdGlv
bj0ic3RvcmUiLAogICAgICAgIGhlbHA9JycnCiAgICAgICAgICAgICBFbmFibGUgbW9kdWxlIHN0
cmVhbXMgaW4gdGhlIG1vZHVsZSBsaXN0IGFuZCBtYWtlIHRoZSBzdHJlYW0gUlBNcyBhdmFpbGFi
bGUgaW4gdGhlIHBhY2thZ2Ugc2V0LgogICAgICAgICAgICAgU3VwcG9ydCB0byBlbmFibGUgbXVs
dGlwbGUgbW9kdWxlcyBhdCBvbmNlLCB3aGljaCBhcmUgc2VwYXJhdGVkIGJ5IHNwYWNlLiBFeGFt
cGxlOgogICAgICAgICAgICAgRW5hYmxlIHNsb3cgdHJhaW4gdmlydCBtb2R1bGU6IC0tZW5hYmxl
LW1vZHVsZSAndmlydDpyaGVsJwogICAgICAgICAgICAgRW5hYmxlIGZhc3QgdHJhaW4gdmlydCBt
b2R1bGU6IC0tZW5hYmxlLW1vZHVsZSAndmlydDo4LjAnCiAgICAgICAgICAgICAnJycKICAgICkK
ICAgIHBhcnNlci5hZGRfYXJndW1lbnQoCiAgICAgICAgJy0tZGlzYWJsZS1tb2R1bGUnLAogICAg
ICAgIGFjdGlvbj0ic3RvcmUiLAogICAgICAgIGhlbHA9JycnCiAgICAgICAgICAgICBEaXNhYmxl
IGEgbW9kdWxlLiBBbGwgcmVsYXRlZCBtb2R1bGUgc3RyZWFtcyB3aWxsIGJlY29tZSB1bmF2YWls
YWJsZS4gU3VwcG9ydCB0byBkaXNhYmxlIG11bHRpcGxlCiAgICAgICAgICAgICBtb2R1bGVzIGF0
IG9uY2UsIHdoaWNoIGFyZSBzZXBhcmF0ZWQgYnkgc3BhY2UuIEV4YW1wbGU6CiAgICAgICAgICAg
ICBEaXNhYmxlIHZpcnQgbW9kdWxlOiAtLWRpc2FibGUtbW9kdWxlICd2aXJ0JyBvciAtLWRpc2Fi
bGUtbW9kdWxlICd2aXJ0OnJoZWwnCiAgICAgICAgICAgICAnJycKICAgICkKICAgIHBhcnNlci5h
ZGRfYXJndW1lbnQoCiAgICAgICAgJy0taW5zdGFsbC1tb2R1bGUnLAogICAgICAgIGFjdGlvbj0i
c3RvcmUiLAogICAgICAgIGhlbHA9JycnCiAgICAgICAgICAgICBJbnN0YWxsIG1vZHVsZSBwcm9m
aWxlcyBpbmNsLiB0aGVpciBSUE1zLiBJbiBjYXNlIG5vIHByb2ZpbGUgd2FzIHByb3ZpZGVkLCBh
bGwgZGVmYXVsdCBwcm9maWxlcyBnZXQKICAgICAgICAgICAgIGluc3RhbGxlZC4gTW9kdWxlIHN0
cmVhbXMgZ2V0IGVuYWJsZWQgYWNjb3JkaW5nbHkuIFN1cHBvcnQgdG8gaW5zdGFsbCBtdWx0aXBs
ZSBtb2R1bGVzIGF0IG9uY2UsIHdoaWNoCiAgICAgICAgICAgICBhcmUgc2VwYXJhdGVkIGJ5IHNw
YWNlLiBFeGFtcGxlOgogICAgICAgICAgICAgSW5zdGFsbCBzbG93IHRyYWluIHZpcnQgbW9kdWxl
OiAtLWluc3RhbGwtbW9kdWxlICd2aXJ0OnJoZWwnCiAgICAgICAgICAgICBJbnN0YWxsIGZhc3Qg
dHJhaW4gdmlydCBtb2R1bGU6IC0taW5zdGFsbC1tb2R1bGUgJ3ZpcnQ6OC4wJwogICAgICAgICAg
ICAgJycnCiAgICApCiAgICBwYXJzZXIuYWRkX2FyZ3VtZW50KAogICAgICAgICctLWluc3RhbGwt
cmVwb3BrZycsCiAgICAgICAgYWN0aW9uPSJzdG9yZSIsCiAgICAgICAgaGVscD0nJycKICAgICAg
ICAgICAgIEluc3RhbGwgdGhlIHBhY2thZ2UgYW5kIHRoZSBkZXBlbmRlbmNpZXMgZnJvbSBhbnkg
ZW5hYmxlZCByZXBvc2l0b3J5LiBTdXBwb3J0IHRvIGluc3RhbGwgbXVsdGlwbGUKICAgICAgICAg
ICAgIHBhY2thZ2VzIGF0IG9uY2UsIHdoaWNoIGFyZSBzZXBhcmF0ZWQgYnkgc3BhY2UuIEV4YW1w
bGU6CiAgICAgICAgICAgICBJbnN0YWxsIHFlbXUta3ZtIGFuZCBxZW11LWt2bS1kZWJ1Z2luZm86
IC0taW5zdGFsbC1yZXBvcGtnICdxZW11LWt2bSBxZW11LWt2bS1kZWJ1Z2luZm8nCiAgICAgICAg
ICAgICAnJycKICAgICkKICAgIHBhcnNlci5hZGRfYXJndW1lbnQoCiAgICAgICAgJy0taW5zdGFs
bC1icmV3cGtnJywKICAgICAgICBhY3Rpb249InN0b3JlIiwKICAgICAgICBoZWxwPScnJwogICAg
ICAgICAgICAgSW5zdGFsbCB0aGUgcGFja2FnZSBhbmQgdGhlIGRlcGVuZGVuY2llcyBmcm9tIGJy
ZXcuIFN1cHBvcnQgdG8gaW5zdGFsbCBtdWx0aXBsZSBwYWNrYWdlcyBhdCBvbmNlLAogICAgICAg
ICAgICAgd2hpY2ggYXJlIHNlcGFyYXRlZCBieSBzcGFjZS4gRXhhbXBsZToKICAgICAgICAgICAg
IEluc3RhbGwgc3BlY2lmaWVkIHFlbXU6IC0taW5zdGFsbC1icmV3cGtnICdxZW11LWt2bS1yaGV2
LTIuMTIuMC0yMS5lbDcnCiAgICAgICAgICAgICBJbnN0YWxsIHRoZSBsYXRlc3QgcGFja2FnZTog
LS1pbnN0YWxsLWJyZXdwa2cgJ3FlbXUta3ZtLXJoZXZAcmhldmgtcmhlbC03LjYtY2FuZGlkYXRl
JwogICAgICAgICAgICAgSW5zdGFsbCB0aGUgc3BlY2lmaWMgUlBNczoKICAgICAgICAgICAgIC0t
aW5zdGFsbC1icmV3cGtnICdxZW11LWt2bS1yaGV2QHJoZXZoLXJoZWwtNy42LWNhbmRpZGF0ZS9x
ZW11LWltZy1yaGV2LHFlbXUta3ZtLXJoZXYnCiAgICAgICAgICAgICBJbnN0YWxsIHRoZSBzcGVj
aWZpYyBSUE1zIHdpdGggc3BlY2lmaWMgYXJjaGl0ZWN0dXJlOgogICAgICAgICAgICAgLS1pbnN0
YWxsLWJyZXdwa2cgJ3FlbXUta3ZtLXJoZXZAcmhldmgtcmhlbC03LjYtY2FuZGlkYXRlL3FlbXUt
aW1nLXJoZXYscWVtdS1rdm0tcmhldi9wcGM2NGxlLG5vYXJjaCcKICAgICAgICAgICAgICcnJwog
ICAgKQogICAgcGFyc2VyLmFkZF9hcmd1bWVudCgKICAgICAgICAnLS1pbnN0YWxsLXZpcnRxZW11
JywKICAgICAgICBhY3Rpb249InN0b3JlIiwKICAgICAgICBoZWxwPScnJwogICAgICAgICAgICAg
SW5zdGFsbCBxZW11IGFuZCBxZW11IGRlcGVuZGVuY2llcyBpbmNsdWRlZCBhIHZpcnQgbW9kdWxl
LiBPdGhlciBwYWNrYWdlcyBsaWtlIGxpYnZpcnQgd291bGRuJ3QgYmUKICAgICAgICAgICAgIGlu
c3RhbGxlZC4gVGhlIGFyZ3VtZW50IGNvdWxkIG1vZHVsZSBpZCwgcWVtdSBwYWNrYWdlLCBrb2pp
IHRhZywgYW5kIG1vZHVsZSBuYW1lIHdpdGggc3RyZWFtLiBFeGFtcGxlOgogICAgICAgICAgICAg
TW9kdWxlIGlkOiAtLWluc3RhbGwtdmlydHFlbXUgJzMxNDMnCiAgICAgICAgICAgICBRRU1VIHBh
Y2thZ2U6IC0taW5zdGFsbC12aXJ0cWVtdSAncWVtdS1rdm0tMi4xMi4wLTY5Lm1vZHVsZStlbDgu
MS4wKzMxNDMrNDU3Zjk4NGMnCiAgICAgICAgICAgICBLb2ppIHRhZzogLS1pbnN0YWxsLXZpcnRx
ZW11ICdtb2R1bGUtdmlydC1yaGVsLTgwMTAwMjAxOTA1MDMwMDAxNDItY2RjMTIwMmInCiAgICAg
ICAgICAgICBNb2R1bGUgbmFtZTogLS1pbnN0YWxsLXZpcnRxZW11ICd2aXJ0OnJoZWw6OC4xLjAn
IG9yIC0taW5zdGFsbC12aXJ0cWVtdSAndmlydDo4LjA6OC4wLjEnCiAgICAgICAgICAgICAnJycK
ICAgICkKICAgIHBhcnNlci5hZGRfYXJndW1lbnQoCiAgICAgICAgJy12JywgJy0tdmVyYm9zZScs
CiAgICAgICAgYWN0aW9uPSJzdG9yZV90cnVlIiwKICAgICAgICBkZWZhdWx0PUZhbHNlLAogICAg
ICAgIGhlbHA9JycnCiAgICAgICAgICAgICBnaXZlIGRldGFpbGVkIG91dHB1dAogICAgICAgICAg
ICAgJycnCiAgICApCiAgICBwYXJzZXIuYWRkX2FyZ3VtZW50KAogICAgICAgICctcScsICctLXF1
aWV0JywKICAgICAgICBhY3Rpb249InN0b3JlX3RydWUiLAogICAgICAgIGRlZmF1bHQ9RmFsc2Us
CiAgICAgICAgaGVscD0nJycKICAgICAgICAgICAgIGdpdmUgbGVzcyBvdXRwdXQKICAgICAgICAg
ICAgICcnJwogICAgKQogICAgcGFyc2VyLmFkZF9hcmd1bWVudCgKICAgICAgICAnLWQnLCAnLS1k
b3duZ3JhZGUnLAogICAgICAgIGFjdGlvbj0ic3RvcmVfdHJ1ZSIsCiAgICAgICAgZGVmYXVsdD1G
YWxzZSwKICAgICAgICBoZWxwPScnJwogICAgICAgICAgICAgZG93bmdyYWRlIG1vZHVsZSB2ZXJz
aW9uIHdoZW4gdGhlcmUgaXMgbm8gYXZhaWxhYmxlIG1vZHVsZSBmb3IgY3VycmVudCByZWxlYXNl
CiAgICAgICAgICAgICAnJycKICAgICkKICAgIHJldHVybiB2YXJzKHBhcnNlci5wYXJzZV9hcmdz
KCkpCgppZiBfX25hbWVfXyA9PSAiX19tYWluX18iOgogICAgb3B0cyA9IHBhcnNlX29wdHMoKQog
ICAgaWYgb3B0cy5nZXQoInZlcmJvc2UiKToKICAgICAgICBMT0dfTFZMID0gNAogICAgaWYgb3B0
cy5nZXQoInF1aWV0Iik6CiAgICAgICAgUVVJRVQgPSBUcnVlCiAgICBpZiBvcHRzLmdldCgiZG93
bmdyYWRlIik6CiAgICAgICAgRE9XTkdSQURFID0gVHJ1ZQogICAgaWYgX2hhc19jbWQoJ3B5dGhv
bjMnKToKICAgICAgICBQWVRIT05fTU9EVUxFX0xJU1QgPSAicHl0aG9uMy1weXlhbWwiCiAgICBp
ZiBfaGFzX2NtZCgnZG5mJyk6CiAgICAgICAgUEtHX01HTVRfQklOPSJkbmYiCiAgICAgICAgX2lu
c3RhbGxfcGtnX2xpc3QoUFlUSE9OX01PRFVMRV9MSVNUKQogICAgICAgIGVuYWJsZV9tb2Qob3B0
cy5nZXQoImVuYWJsZV9tb2R1bGUiKSkKICAgICAgICBkaXNhYmxlX21vZChvcHRzLmdldCgiZGlz
YWJsZV9tb2R1bGUiKSkKICAgICAgICBpbnN0YWxsX21vZChvcHRzLmdldCgiaW5zdGFsbF9tb2R1
bGUiKSkKICAgICAgICBpbnN0YWxsX3ZpcnRfcWVtdV9mcm9tX2JyZXcob3B0cy5nZXQoImluc3Rh
bGxfdmlydHFlbXUiKSkKICAgIGluc3RhbGxfcGtnX2Zyb21fcmVwbyhvcHRzLmdldCgiaW5zdGFs
bF9yZXBvcGtnIikpCiAgICBpbnN0YWxsX3BrZ19mcm9tX2JyZXcob3B0cy5nZXQoImluc3RhbGxf
YnJld3BrZyIpKQo=
EOF
chmod a+rx /root/component_management.py
## End 'component_management.py'

# Remove the kernel args we dont like
grubby --remove-args="rhgb quiet" --update-kernel=$(grubby --default-kernel)

sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
systemctl enable kdump.service
systemctl enable rpcbind.service
systemctl enable NetworkManager.service
systemctl enable sshd.service
systemctl enable nfs-server.service
systemctl disable firewalld.service
systemctl disable user.slice

# change the open files and the core size
host_memory_amount=$(awk '( $1 == "MemTotal:" ) { printf "%d", $2/1024/1024 }' /proc/meminfo)
echo "ProcessSizeMax=${host_memory_amount}G" >> /etc/systemd/coredump.conf
echo "ExternalSizeMax=${host_memory_amount}G" >> /etc/systemd/coredump.conf
echo "*               hard    nofile            8192" >> /etc/security/limits.conf

if ! ping "github.com" -c 5; then
    echo "export https_proxy=http://squid.corp.redhat.com:3128" >> /etc/profile
fi
dnf install -y 'https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm'
%end

%packages --ignoremissing
dosfstools
edk2-ovmf
gcc
gcc-c++
glibc-headers
git
gstreamer1-plugins-good
httpd
iproute
iputils
iscsi-initiator-utils
lftp
mkisofs
nfs-utils
nmap-ncat
numactl
patch
python3-devel
python3-gobject
python3-pillow
rpcbind
screen
sg3_utils
sysstat
targetcli
tcpdump
telnet
telnet-server
vsftpd
xinetd
%end
]]></ks>
