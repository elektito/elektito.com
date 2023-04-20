#!/usr/bin/env sh

set -e

GO_VERSION=${GO_VERSION:-1.20.2}
GOLANG_MIGRATE_VERSION=${GOLANG_MIGRATE_VERSION:-4.15.2}

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

useradd gemplex || true
groupadd gemplex-deployment || true

apt update
apt install -y nginx postgresql-14

if [ ! -e /usr/local/go ]; then
  curl -L "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o go.tar.gz
  tar -C /usr/local -xzf go.tar.gz
fi

if [ ! -e /usr/local/bin/migrate ]; then
  curl -L "https://github.com/golang-migrate/migrate/releases/download/v${GOLANG_MIGRATE_VERSION}/migrate.linux-amd64.tar.gz" -o migrate.tar.gz
  tar -C /usr/local/bin -xf migrate.tar.gz migrate
fi

# Not really necessary for this script, but helpful if the root user wants to
# run some go commands manually.
if ! grep 'PATH=$PATH:/usr/local/go/bin' ~/.bashrc >/dev/null ; then
    echo 'PATH=$PATH:/usr/local/go/bin' >>~/.bashrc
fi

export GOBIN=/usr/local/go/bin
export GOPROXY=direct
/usr/local/go/bin/go install git.sr.ht/~elektito/hodhod@latest

rm -rf gemplex
git clone --depth=1 https://git.sr.ht/~elektito/gemplex
cd gemplex
make release
make install
cd ..

mkdir -p /var/gemini

chown gemplex:gemplex-deployment root/ -R
chmod 0730 root/ -R
cp -r root/* /

rsync -r --delete gemplex/capsule/ /var/gemini/gemplex.space/

rm -rf elektito.com-gemini
git clone https://github.com/elektito/elektito.com-gemini.git
rsync -r --delete elektito.com-gemini/capsule/ /var/gemini/elektito.com/

mkdir -p /etc/gemini/certs
cp elektito.com.key /etc/gemini/certs/
cp elektito.com.cer /etc/gemini/certs/
cp gemplex.space.key /etc/gemini/certs/
cp gemplex.space.cer /etc/gemini/certs/

mkdir -p /var/lib/gemplex

sudo -u postgres psql -c 'create database gemplex' || true
sudo -u postgres psql -c 'create role gemplex' || true
sudo -u postgres psql -c 'grant all on database gemplex to gemplex' || true

echo "Migrating database..."
cp -r gemplex/db/migrations /tmp
chown -R gemplex:gemplex /tmp/migrations/
sudo -u gemplex migrate -database postgres:///gemplex?host=/var/run/postgresql -path /tmp/migrations/ up

echo "Fixing permissions"
chown gemplex:gemplex-deployment /opt/gemplex/ -R
chmod 0730 /opt/gemplex/ -R

echo "Reloading and restarting stuff..."
systemctl daemon-reload

systemctl enable hodhod
systemctl restart hodhod

systemctl enable gemplex
systemctl restart gemplex

systemctl reload nginx

echo "Done."
