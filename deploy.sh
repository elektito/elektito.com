#!/usr/bin/env sh

set -e

GO_VERSION=${GO_VERSION:-1.20.2}

if [ "$(id -u)" -ne 0 ]; then
  echo "The script needs to be run as root."
  exit 1
fi

if [ ! -f "key.pem" ]; then
    echo "key.pem does not exist."
    exit 1
fi

if [ ! -f "cert.pem" ]; then
    echo "cert.pem does not exist."
    exit 1
fi

apt update
apt install -y nginx

curl -L "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o go.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go.tar.gz

# Not really necessary for this script, but helpful if the root user wants to
# run some go commands manually.
if ! grep 'PATH=$PATH:/usr/local/go/bin' ~/.bashrc >/dev/null ; then
    echo 'PATH=$PATH:/usr/local/go/bin' >>~/.bashrc
fi

GOBIN=/usr/local/go/bin /usr/local/go/bin/go install github.com/elektito/hodhod@latest

mkdir -p /var/gemini

cp -r root/* /
rm -rf elektito.com-gemini
git clone https://github.com/elektito/elektito.com-gemini.git
rsync -r --delete elektito.com-gemini/capsule/ /var/gemini/gem/

mkdir -p /etc/gemini/certs
cp key.pem /etc/gemini/certs/elektito.com.key
cp cert.pem /etc/gemini/certs/elektito.com.cer

systemctl daemon-reload

systemctl enable hodhod
systemctl restart hodhod

systemctl reload nginx
