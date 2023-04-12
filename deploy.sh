#!/usr/bin/env sh

set -e

GO_VERSION=${GO_VERSION:-1.20.2}

if [ "$(id -u)" -ne 0 ]; then
  echo "The script needs to be run as root."
  exit 1
fi

files="elektito.com.cer elektito.com.key gemplex.space.cer gemplex.space.key"

for file in ${files}; do
  if [ ! -f "$file" ]; then
    echo "$file does not exist."
    exit 1
  fi
done

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

rm -rf gemplex
git clone --depth=1 https://github.com/elektito/gemplex.git
cd gemplex
make release
make install
cd ..

mkdir -p /var/gemini

cp -r root/* /

rm -rf elektito.com-gemini
git clone https://github.com/elektito/elektito.com-gemini.git
rsync -r --delete elektito.com-gemini/capsule/ /var/gemini/elektito.com/

rm -rf gemplex
git clone https://github.com/elektito/gemplex.git
rsync -r --delete gemplex/capsule/ /var/gemini/gemplex.space/

mkdir -p /etc/gemini/certs
cp elektito.com.key /etc/gemini/certs/
cp elektito.com.cer /etc/gemini/certs/
cp gemplex.space.key /etc/gemini/certs/
cp gemplex.space.cer /etc/gemini/certs/

systemctl daemon-reload

systemctl enable hodhod
systemctl restart hodhod

systemctl enable gemplex
systemctl restart gemplex

systemctl reload nginx
