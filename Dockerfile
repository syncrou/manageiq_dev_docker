FROM centos:7
MAINTAINER Drew Bomhof (syncrou) https://github.com/syncrou

# Set ENV, LANG only needed if building with docker-1.8
ENV LANG en_US.UTF-8
ENV TERM xterm
ENV APP_ROOT manageiq

## Install EPEL repo, yum necessary packages for the build without docs, clean all caches
RUN yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum -y install --setopt=tsflags=nodocs \
                   bison                   \
                   bzip2                   \
                   cmake                   \
                   file                    \
                   gcc-c++                 \
                   git                     \
                   libffi-devel            \
                   libtool                 \
                   libxml2-devel           \
                   libxslt-devel           \
                   libyaml-devel           \
                   make                    \
                   memcached               \
                   net-tools               \
                   nodejs                  \
                   openssl-devel           \
                   patch                   \
                   postgresql-devel        \
                   readline-devel          \
                   sqlite-devel            \
                   sysvinit-tools          \
                   which                   \
                   httpd                   \
                   mod_ssl                 \
                   mod_auth_kerb           \
                   mod_authnz_pam          \
                   mod_intercept_form_submit \
                   mod_lookup_identity     \
                   initscripts             \
                   npm                     \
                   chrony                  \
                   psmisc                  \
                   lvm2                    \
                   openldap-clients        \
                   gdbm-devel              \
                   &&                      \
    yum clean all


# Download chruby and chruby-install, install, setup environment, clean all
RUN curl -sL https://github.com/postmodern/chruby/archive/v0.3.9.tar.gz | tar xz && \
    cd chruby-0.3.9 && make install && scripts/setup.sh && \
    echo "gem: --no-ri --no-rdoc --no-document" > ~/.gemrc && \
    echo "source /usr/local/share/chruby/chruby.sh" >> ~/.bashrc && \ 
    curl -sL https://github.com/postmodern/ruby-install/archive/v0.6.0.tar.gz | tar xz && \
    cd ruby-install-0.6.0 && make install && ruby-install ruby 2.2.4 -- --disable-install-doc && \
    echo "chruby ruby-2.2.4" >> ~/.bash_profile && \
    rm -rf /chruby-* && rm -rf /usr/local/src/* && yum clean all

## GIT clone manageiq-appliance and self-service UI repo (SSUI)
RUN git clone --depth 1 https://github.com/ManageIQ/manageiq.git ${APP_ROOT} # && \

## Create approot, ADD miq
RUN mkdir -p ${APP_ROOT}
ADD . ${APP_ROOT}

## Add bundler and gems database.yml and postgres env
RUN echo "export PATH=\$PATH:/opt/rubies/ruby-2.2.4/bin:/opt/rubies/ruby-2.2.4/bin" >> ~/.bashrc && \
echo "export APP_ROOT=${APP_ROOT}" >> ~/.bashrc

COPY database.yml ${APP_ROOT}/config/
RUN curl -sL http://rubygems.org/rubygems/rubygems-2.6.4.tgz | tar xz && \
    cd rubygems-2.6.4 && \
    /opt/rubies/ruby-2.2.4/bin/ruby ./setup.rb

## Change workdir to application root, build/install gems
WORKDIR ${APP_ROOT}
RUN /usr/bin/memcached -u memcached -p 11211 -m 64 -c 1024 -l 127.0.0.1 -d && \
npm install npm -g && \
npm install gulp bower -g && \
/opt/rubies/ruby-2.2.4/bin/gem install bundler -v ">=1.8.4" && \
#bin/update && \
rm -rvf /opt/rubies/ruby-2.2.4/lib/ruby/gems/2.2.0/cache/*
#bower cache clean && \
#npm cache clean

## Enable services on systemd
RUN systemctl enable memcached #miqtop

## Expose required container ports
EXPOSE 3000
