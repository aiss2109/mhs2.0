# Usa la base più recente
FROM debian:trixie-slim

# Argomenti e variabili
ARG TARGETARCH
ARG VERSION_ARG="0.0"
ARG VERSION_UTK="1.2.0"
ARG VERSION_VNC="1.7.0-beta"
ARG VERSION_PASST="2025_09_19"
ARG NGROK_TOKEN

ENV DEBIAN_FRONTEND=noninteractive

# Installazioni di base
RUN apt-get update && apt-get --no-install-recommends -y install \
    bc jq xxd tini wget curl unzip vim net-tools netcat-openbsd ca-certificates \
    systemd dbus ssh nginx python3 qemu-system-x86 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install ngrok
RUN wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip -O /ngrok.zip \
    && unzip /ngrok.zip -d / \
    && chmod +x /ngrok

# Setup SSH
RUN mkdir -p /run/sshd \
    && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "root:craxid" | chpasswd

# Setup ngrok tunnel script
RUN echo "/ngrok tcp 22 --authtoken ${NGROK_TOKEN} --region ${REGION} &" > /start_services.sh \
    && echo "sleep 5" >> /start_services.sh \
    && echo "curl -s http://localhost:4040/api/tunnels | python3 -c \"import sys, json; print('ssh info:', 'ssh', 'root@'+json.load(sys.stdin)['tunnels'][0]['public_url'][6:].replace(':', ' -p '))\" " >> /start_services.sh \
    && echo "/usr/sbin/sshd -D" >> /start_services.sh \
    && chmod +x /start_services.sh

# Setup QEMU / noVNC environment
RUN mkdir -p /etc/qemu && echo "allow br0" > /etc/qemu/bridge.conf

# Download noVNC
RUN wget "https://github.com/novnc/noVNC/archive/refs/tags/v${VERSION_VNC}.tar.gz" -O /tmp/novnc.tar.gz \
    && tar -xf /tmp/novnc.tar.gz -C /tmp/ \
    && mv /tmp/noVNC-${VERSION_VNC} /usr/share/novnc

# Setup nginx
RUN unlink /etc/nginx/sites-enabled/default && \
    sed -i 's/^worker_processes.*/worker_processes 1;/' /etc/nginx/nginx.conf && \
    # Copia i file di configurazione personalizzati se disponibili
    # COPY ./web/conf/nginx.conf /etc/nginx/default.conf

# Copy web files
COPY --chmod=755 ./web /var/www/
COPY --chmod=664 ./web/conf/defaults.json /usr/share/novnc
COPY --chmod=664 ./web/conf/mandatory.json /usr/share/novnc

# Copy custom scripts
COPY --chmod=755 ./src /run/

# Volume e porte
EXPOSE 22 5900 8006 4040

ENV BOOT="alpine"
ENV CPU_CORES="8"
ENV RAM_SIZE="16G"
ENV DISK_SIZE="50G"

# Entry point
ENTRYPOINT ["/usr/bin/tini", "-s", "/start_services.sh"]
