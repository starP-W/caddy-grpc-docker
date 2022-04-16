#!/bin/bash

Precheck() {
    DOCKER_V=$(docker -v | grep -i "version")
    DC_V=$(docker-compose -v | grep -i "version")
    if [ -z "${DOCKER_V}" ] || [ -z "${DC_V}" ]; then
        echo "Docker or docker-compose not found. "
        exit 1
    fi

    EssentialFiles="Webdata Caddyfile .settings config.json docker-compose.yml"
    for file in $EssentialFiles; do
        if [ ! -e $file ]; then
            case "${file}" in
            "Caddyfile" | "config.json" | "docker-compose.yml")
                curl -sO "https://raw.githubusercontent.com/starP-W/caddy-grpc-docker/main/${file}"
                ;;
            "tls" | "Webdata")
                mkdir $file
                ;;
            ".settings")
                touch $file
                ;;
            *) ;;
            esac
        fi
    done
}

ChangeSettings() {
    if [ -z "$(grep "$1" ./.settings)" ]; then
        echo "$1=$2" >>./.settings
    else
        sed -i -E "s|$1=.+|$1=$2|g" ./.settings
    fi
}

SetCF() {
    read -p "Please Input Your CloudFlare Mailbox: " MAILBOX
    read -p "Please Input Your CloudFlare API_Key: " APIKEY
    sed -i -E "s|CF_Email=.+|CF_Email=$MAILBOX|g" ./docker-compose.yml
    sed -i -E "s|CF_Key=.+|CF_Key=$APIKEY|g" ./docker-compose.yml
    ChangeSettings "CF_Email" "$MAILBOX"
    ChangeSettings "CF_Key" "$APIKEY"
}

SetCaddy() {
    read -p "Please Input Your Domain(eg. aa.org ): " FQDN
    sed -i -E "1s|^.+ \{|https://$FQDN \{|g" ./Caddyfile
    # servicename跟随UUID一起进行设置
    read -p "Use 1.file_server or 2.reverse_proxy? (Default 1) : " mode
    case "${mode}" in
    2)
        echo "Using reverse_proxy mode"
        read -p "Please Input Your Proxy URL(eg. http(s)://abc.de): " ppppp
        sed -i -E "10,+3s|^#+||g" ./Caddyfile
        sed -i -E "8,+1s|^|#|g" ./Caddyfile
        sed -i -E "10s|reverse_proxy \* .*|reverse_proxy \* $ppppp {|g" ./Caddyfile
        ;;
    *)
        echo "Using file_server mode"
        sed -i -E "10,+3s|^|#|g" ./Caddyfile
        sed -i -E "8,+1s|^#+||g" ./Caddyfile
        ;;
    esac
    ChangeSettings "FQDN" "$FQDN"
}

ChangeCF() {
    iscfset=$(grep 'CF_' ./.settings | awk '{print NR}' | sed -n '$p')
    case "${iscfset}" in
    2)
        read -p "Want to change CloudFlare settings? (yN default N): " changecf
        case "${changecf}" in
        'y' | 'Y')
            SetCF
            ;;
        *) ;;
        esac
        ;;
    *)
        SetCF
        ;;
    esac
}

ChangeCaddy() {
    iscaddyset=$(grep 'FQDN' ./.settings | awk '{print NR}' | sed -n '$p')
    case "${iscaddyset}" in
    1)
        read -p "Want to change domain settings? (yN default N): " changefqdn
        case "${changefqdn}" in
        'y' | 'Y')
            SetCaddy
            ;;
        *) ;;
        esac
        ;;
    *)
        SetCaddy
        ;;
    esac
}

ChangeUUID() {
    UUIDN1=$(curl -s https://www.uuidgenerator.net/api/version4)
    case "$(grep 'UUID' ./.settings | awk '{print NR}' | sed -n '$p')" in
    1)
        read -p "Change the UUID? (y or N def N)" setUUID
        case "${setUUID}" in
        'y' | 'Y')
            sed -i -E "s|\w{8}(-\w{4}){3}-\w{12}\" //GRPC|$UUIDN1\" //GRPC|g" ./config.json
            sed -i -E "s|\"serviceName\": \".*\"|\"serviceName\": \"$UUIDN1\"|g" ./config.json
            sed -i -E "5s|\/.+\/\*|\/$UUIDN1\/\*|g" ./Caddyfile
            ChangeSettings "UUID" "$UUIDN1"
            ;;
        *) ;;
        esac
        ;;
    *)
        sed -i -E "s|\w{8}(-\w{4}){3}-\w{12}\" //GRPC|$UUIDN1\" //GRPC|g" ./config.json
        sed -i -E "s|\"serviceName\": \".*\"|\"serviceName\": \"$UUIDN1\"|g" ./config.json
        sed -i -E "5s|\/.+\/\*|\/$UUIDN1\/\*|g" ./Caddyfile
        ChangeSettings "UUID" "$UUIDN1"
        ;;
    esac
}

Install() {
    Precheck 1
    if [ -e ".settings" ]; then
        UUID=$(grep 'UUID' ./.settings | awk -F= '{print $2}')
        sed -i '/'"$UUID"'/d' /var/spool/cron/crontabs/"$(whoami)"
    fi
    ChangeCF
    ChangeCaddy
    ChangeUUID
    docker-compose down --rmi all
    docker-compose up -d
    FQDN=$(grep FQDN .settings | awk -F= '{print $2}')
    docker-compose exec acme --issue --dns dns_cf -d $FQDN --server letsencrypt
    docker-compose exec acme --install-cert -d $FQDN --key-file /tls/key.key --fullchain-file /tls/cert.crt
    docker-compose restart
    if [ -e "/usr/bin/docker-compose" ]; then
        DockerComposePath="/usr/bin/docker-compose"
        echo "0 0 1 * * cd $PWD && $DockerComposePath restart #$UUID" >>/var/spool/cron/crontabs/"$(whoami)"
    elif [ -e "/usr/local/bin/docker-compose" ]; then
        DockerComposePath="/usr/local/bin/docker-compose"
        echo "0 0 1 * * cd $PWD && $DockerComposePath restart #$UUID" >>/var/spool/cron/crontabs/"$(whoami)"
    fi
}

echo -e "1.install\t2.update\t3.uninstall"
read -p ": " opt
case "${opt}" in
1)
    Install
    ;;
2 | 3)
    echo "还没写"
    ;;
*)
    echo "神奇海螺"
    ;;
esac
