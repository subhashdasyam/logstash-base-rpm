FROM centos
RUN yum groupinstall 'Development Tools' -y && \
    yum install zlib-devel openssl-devel readline-devel libyaml-devel.x86_64 libxml2-devel.x86_64 libxslt-devel.x86_64 java-1.8.0-openjdk-devel iputils nmap-ncat vim rake git curl -y && \
    yum clean all
WORKDIR /root
RUN adduser -d /home/logstash logstash && \
    mkdir -p /usr/local/share/ruby-build && \
    mkdir -p /opt/logstash && \
    mkdir -p /mnt/host && \
    chown logstash:logstash /opt/logstash
USER logstash
WORKDIR /home/logstash

RUN git clone https://github.com/sstephenson/rbenv.git .rbenv && \
    git clone https://github.com/sstephenson/ruby-build.git .rbenv/plugins/ruby-build && \
    echo 'export PATH=/home/logstash/.rbenv/bin:$PATH' >> /home/logstash/.bashrc

ENV PATH "/home/logstash/.rbenv/bin:$PATH"

#Only used to help bootstrap the build (not to run Logstash itself)
RUN echo 'eval "$(rbenv init -)"' >> .bashrc && \
    rbenv install jruby-9.2.5.0 && \
    rbenv global jruby-9.2.5.0 && \
    bash -i -c "gem install bundler" && \
    bash -i -c "gem install rake" && \
    rbenv local jruby-9.2.5.0 && \
    mkdir -p /opt/logstash/data


# Create a cache for the dependencies based on the 5.6 branch, any dependencies not cached will be downloaded at runtime
RUN git clone https://github.com/elastic/logstash.git /tmp/logstash && \
    cd /tmp/logstash && \
    git checkout 5.6 && \
    sed -i 's/2.6.2/2.8.2/g' /tmp/logstash/logstash-core/build.gradle && \
    rake test:install-core
WORKDIR /tmp/logstash
RUN ./gradlew compileJava compileTestJava
RUN cd qa/integration
#RUN grep -E "jruby-1.7.27" -r /home/logstash/
RUN sed -i 's/jruby-1.7.27/jruby-9.2.5.0/g' /tmp/logstash/.ruby-version
RUN /home/logstash/.rbenv/shims/bundle install
RUN mv /tmp/logstash/vendor /tmp/vendor && \
    rm -rf /tmp/logstash

# used by the purge policy
LABEL retention="keep"

# todo update google guava plugin
