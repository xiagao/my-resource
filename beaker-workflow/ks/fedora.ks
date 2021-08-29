<ks><![CDATA[
rootpw --iscrypted $1$bPnySNFo$QCqmVA1sHhddG7v.ivCbA0
# https://github.com/kata-containers/documentation/blob/master/Limitations.md#selinux-support
selinux --disabled

%post
# Some distros have curl in their minimal install set, others have wget.
# We define a wrapper function around the best available implementation
# so that the rest of the script can use that for making HTTP requests.
if command -v curl >/dev/null ; then
    function fetch() {
        curl -kL --retry 5 -o "$1" "$2"
    }
elif command -v wget >/dev/null ; then
    function fetch() {
        wget --tries 5 --no-check-certificate -O "$1" "$2"
    }
else
    echo "No HTTP client command available!"
    function fetch() {
        false
    }
fi

##install certificate
fetch /etc/pki/ca-trust/source/anchors/RH-IT-Root-CA.crt https://password.corp.redhat.com/RH-IT-Root-CA.crt
update-ca-trust enable
update-ca-trust extract

## Install koji
dnf install koji -y
## End koji installation

## Generate 'buildsys createrepo' tool
base64 -d <<EOF > /tmp/createrepo.sh
IyEvYmluL2Jhc2gKX2hhc19jbWQoKSB7IGNvbW1hbmQgLXYgJDEgPi9kZXYvbnVsbDsgcmV0dXJu
ICQ/OyB9CQpfZXhpdF9vbl9lcnJvcigpIHsgaWYgWyAkPyAtbmUgMCBdOyB0aGVuIGVjaG8gLWUg
JCogPiYyOyBleGl0IDE7IGZpOyB9Cl9kb3dubG9hZCgpIHsgY3VybCAta0wgIiQxIiAtbyAiJDIi
OyByZXR1cm4gJD87IH0KX2ZldGNoX2J1aWxkKCkgewogICAgbG9jYWwgX1JQTVMKICAgIF9CVUlM
RD0iJChlY2hvICR7MX0vIHwgY3V0IC1kJy8nIC1mMSkiCiAgICBfVEFHPSIkKGVjaG8gJHtfQlVJ
TER9QCB8IGN1dCAtZCdAJyAtZjIpIjsgX0JVSUxEPSIkKGVjaG8gJHtfQlVJTER9QCB8IGN1dCAt
ZCdAJyAtZjEpIgogICAgX1BLR1M9IiQoZWNobyAkezF9LyB8IGN1dCAtZCcvJyAtZjIpIjsgX1BL
R1M9IiR7X1BLR1MvLywvIH0iCiAgICBfQVJDSD0iJChlY2hvICR7MX0vIHwgY3V0IC1kJy8nIC1m
MykiOyBfQVJDSD0iJHtfQVJDSDotJChhcmNoKSxub2FyY2h9IjsgX0FSQ0g9IiR7X0FSQ0gvLywv
fH0iCgogICAgaWYgWyAtbiAiJHtfVEFHfSIgXTsgdGhlbgogICAgICAgIF9PVVRQVVQ9IiQoJF9C
VUlMRFNZU19CSU4gbGF0ZXN0LWJ1aWxkICRfVEFHICRfQlVJTEQgLS1xdWlldCAyPiYxKSIKICAg
ICAgICBfZXhpdF9vbl9lcnJvciAiRmFpbGVkIHRvIGdldCB0aGUgbGF0ZXN0IGJ1aWxkIG9mICck
X0JVSUxEICgkX1RBRyknLCBjb21tYW5kIG91dHB1dDpcbiRfT1VUUFVUIgogICAgICAgIF9CVUlM
RD0iJChlY2hvICRfT1VUUFVUIHwgY3V0IC1kJyAnIC1mMSkiCiAgICBmaQogICAgX09VVFBVVD0i
JCgkX0JVSUxEU1lTX0JJTiBidWlsZGluZm8gJF9CVUlMRCAyPiYxKSIKICAgIF9leGl0X29uX2Vy
cm9yICJGYWlsZWQgdG8gZ2V0IGJ1aWxkIGluZm9tYXRpb24gb2YgJyRfQlVJTEQnLCBjb21tYW5k
IG91dHB1dDpcbiRfT1VUUFVUIgogICAgX1VSTFM9JChlY2hvICRfT1VUUFVUIHwgdHIgJyAnICdc
bicgfCBncmVwIC1FICIkX0FSQ0hcLnJwbSIgfCBzZWQgInM7JF9UT1BESVI7JF9UT1BVUkw7ZyIp
CgogICAgZm9yIF9QS0cgaW4gJF9QS0dTOyBkbwogICAgICAgIF9IQVNfUEtHPSIiCiAgICAgICAg
Zm9yIF9VUkwgaW4gJF9VUkxTOyBkbwogICAgICAgICAgICBfTlZSPSR7X1VSTCMjKi99OyBfTlY9
JHtfTlZSJS0qfTsgX049JHtfTlYlLSp9CiAgICAgICAgICAgIGlmIFsgIiRfUEtHIiA9PSAiJF9O
IiBdOyB0aGVuIF9IQVNfUEtHPSIkX1VSTCI7IGJyZWFrOyBmaQogICAgICAgIGRvbmUKICAgICAg
ICBpZiBbIC16ICIkX0hBU19QS0ciIF07IHRoZW4gZWNobyAiJyRfUEtHJyBpcyBub3QgaW4gJyRf
QlVJTEQnLCBza2lwcGVkIiA+JjI7IGNvbnRpbnVlOyBmaQogICAgICAgIF9SUE1TPSgke19SUE1T
W0BdfSAkX0hBU19QS0cpCiAgICBkb25lCiAgICBfUlBNUz0ke19SUE1TOi0kX1VSTFN9CiAgICBl
Y2hvICIkX1JQTVMiCn0KX2NyZWF0ZV9yZXBvKCkgewogICAgbG9jYWwgX1JFUE89IiQxIgogICAg
bG9jYWwgX05BTUU9JChiYXNlbmFtZSAkX1JFUE8pCiAgICBjaG93biAtUiByb290LnJvb3QgJF9S
RVBPCiAgICBjcmVhdGVyZXBvICIkX1JFUE8iCiAgICBfZXhpdF9vbl9lcnJvciAiRmFpbGVkIHRv
IGNyZWF0ZSByZXBvIGZvciAnJF9SRVBPJyIKICAgIGNhdCA+L2V0Yy95dW0ucmVwb3MuZC8ke19O
QU1FfS5yZXBvIDw8RU9GClskX05BTUVdCm5hbWU9TG9jYWwgcmVwbyAtICRfTkFNRQpiYXNldXJs
PWZpbGU6Ly8kX1JFUE8KZW5hYmxlZD0xCmdwZ2NoZWNrPTAKRU9GCiAgICBjaG1vZCAtUiBvLXcr
ciAkX1JFUE8KfQoKX1RPUFVSTD0iaHR0cHM6Ly9rb2ppcGtncy5mZWRvcmFwcm9qZWN0Lm9yZyIK
X1RPUERJUj0iL21udC9rb2ppIgpfaGFzX2NtZCAiY3JlYXRlcmVwbyIKX2V4aXRfb25fZXJyb3Ig
Ik1pc3NpbmcgY29tbWFuZCAnY3JlYXRlcmVwbyciCl9oYXNfY21kICJjdXJsIgpfZXhpdF9vbl9l
cnJvciAiTWlzc2luZyBjb21tYW5kICdjdXJsJyIKX2hhc19jbWQgImtvamkiICYmIF9CVUlMRFNZ
U19CSU49ImtvamkiCl9leGl0X29uX2Vycm9yICJNaXNzaW5nIGNvbW1hbmQgJ2tvamknIgpfaGFz
X2NtZCAiYnJldyIgJiYgX0JVSUxEU1lTX0JJTj0iYnJldyIgJiYgX1RPUFVSTD0iaHR0cDovL2Rv
d25sb2FkLmRldmVsLnJlZGhhdC5jb20iICYmIF9UT1BESVI9Ii9tbnQvcmVkaGF0IgpfVEFSR0VU
Uz0iIgpmb3IgX0JVSUxEX1JFUSBpbiAkQDsgZG8gX1RBUkdFVFM9IiRfVEFSR0VUUyAkKF9mZXRj
aF9idWlsZCAkX0JVSUxEX1JFUSkiOyBkb25lCmlmIFsgLXogIiRfVEFSR0VUUyIgXTsgdGhlbiBl
eGl0IDA7IGZpCl9SRVBPX0RJUj0iL29wdC9sb2NhbHJlcG8tJChkYXRlICsnJVklbSVkLSVIJU0l
UycpLSRSQU5ET00iCm1rZGlyIC1wICRfUkVQT19ESVIKZm9yIF9UQVJHRVQgaW4gJHtfVEFSR0VU
U1tAXX07IGRvCiAgICBfZG93bmxvYWQgIiRfVEFSR0VUIiAiJHtfUkVQT19ESVJ9LyQoYmFzZW5h
bWUgJF9UQVJHRVQpIgogICAgX2V4aXRfb25fZXJyb3IgIkZhaWxlZCB0byBkb3dubG9hZCBycG0g
cGFja2FnZSAnJF9UQVJHRVQnIgpkb25lCl9jcmVhdGVfcmVwbyAiJF9SRVBPX0RJUiIK
EOF
install -m0755 "/tmp/createrepo.sh" "/usr/local/bin/kvmqe-buildsys-createrepo"
## End 'buildsys createrepo' tool

## Clone kata tests repo
git clone 'https://gitlab.cee.redhat.com/xuhan/kata-tests.git' /root/kata-tests

systemctl enable kdump.service
systemctl enable sshd.service
systemctl disable firewalld.service
systemctl disable user.slice

# change the open files and the core size
#host_memory_amount=$(awk '( $1 == "MemTotal:" ) { printf "%d", $2/1024/1024 }' /proc/meminfo)
#echo "ProcessSizeMax=${host_memory_amount}G" >> /etc/systemd/coredump.conf
#echo "ExternalSizeMax=${host_memory_amount}G" >> /etc/systemd/coredump.conf
#echo "*               hard    nofile            8192" >> /etc/security/limits.conf

git config --system http.proxy http://squid.corp.redhat.com:3128
%end

%packages --ignoremissing
createrepo_c
git
golang
%end
]]></ks>
