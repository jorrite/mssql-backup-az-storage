FROM ubuntu:xenial-20200326

RUN groupadd -g 901 mssql-backup && useradd -m -g mssql-backup -u 901 mssql-backup 

RUN apt-get update && \
    apt-get install -y \
    ca-certificates \ 
    curl=7.47.0-1ubuntu2.14 \
    apt-transport-https=1.2.32 \
    lsb-release=9.20160110ubuntu0.2 \
    gnupg=1.4.20-1ubuntu3.3 \
    libunwind8=1.1-4.1 \
    libicu55=55.1-7ubuntu0.5 \
    unzip=6.0-20ubuntu1 \ 
    jq=1.5+dfsg-1ubuntu0.1

RUN curl -sL https://packages.microsoft.com/keys/microsoft.asc | \
    gpg --dearmor | \
    tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null

RUN echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/azure-cli.list

RUN apt-get update && \
    apt-get install -y \
    azure-cli=2.5.1-1~xenial

RUN mkdir -p /opt/ms/sqlpackage \
    && curl -L -o sqlpackage.zip https://go.microsoft.com/fwlink/?linkid=873926 \
    && unzip sqlpackage.zip -d /opt/ms/sqlpackage \
    && chmod +x /opt/ms/sqlpackage/sqlpackage \
    && rm sqlpackage.zip

ENV PATH="/opt/ms/sqlpackage:${PATH}"
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

WORKDIR /home/mssql-backup 
COPY backup.sh .
RUN chmod +x backup.sh

USER mssql-backup
ENTRYPOINT ["/tini", "--"]
CMD ["/home/mssql-backup/backup.sh"]
