FROM operaimg/ubuntu_base:1.2

ENV TZ=America/New_York 
ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /acl_test

RUN  apt-get update && \
     apt-get install -y libpcre3 libpcre3-dev php php-apcu php-intl php-mbstring php-xml php-mysql php-bz2 composer

RUN pip3 install --no-cache-dir bs4 mwxml numpy

CMD /bin/zsh
