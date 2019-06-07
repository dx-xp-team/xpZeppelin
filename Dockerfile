# First section builds a tempory docker image to compile Zeppelin
# To avoid all the build dependencies to be part of the final Zeppelin image, a second image (runner) is build
# and the target of the compilation is copied into that image
FROM centos:7.3.1611 as builder
# Need to install epel-release prior to npm otherwise it doesn't find npn package
RUN yum -y install epel-release >/dev/null
RUN yum -y install gcc python-devel git java-1.8.0-openjdk-devel npm fontconfig which bzip2 make; yum clean all >/dev/null
RUN yum -y groupinstall 'Development Tools' >/dev/null
RUN yum install -y libcurl-devel openssl-devel libxml2-devel >/dev/null
RUN yum install -y R >/dev/null
COPY installEvaluate.r /tmp
# Fix "ERROR: dependency 'evaluate' is not available for package 'rzeppelin'"
RUN Rscript /tmp/installEvaluate.r
RUN curl -s http://www.eu.apache.org/dist/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz | tar xz -C /usr/local/
RUN ln -s /usr/local/apache-maven-3.3.9/bin/mvn /usr/local/bin/mvn
RUN export MAVEN_OPTS="-Xmx2g -XX:MaxPermSize=1024m"

RUN mkdir /var/zeppelin
RUN git clone https://github.com/apache/zeppelin.git  /var/zeppelin/

RUN /var/zeppelin/dev/change_scala_version.sh 2.11

# Fix "Cannot find where you keep your Bower packages. Use --force to continue test new automated build"
RUN cd /var/zeppelin/zeppelin-web;npm install -g bower;bower --allow-root install

# building with -Pspark-2.3 failed to execute goal on project spark-scala-2.10
RUN cd /var/zeppelin; mvn -X --batch-mode --no-transfer-progress package -Pbuild-distr -DskipTests -Pspark-2.2 -Phadoop-2.7 -Pyarn -Ppyspark -Psparkr -Pr -Pscala-2.11

# Building the Zeppelin image based on compilation done in  builder image
FROM dxxpteam/xpspark:2.3p3.6.4
RUN apt-get -y install gcc
COPY --from=builder /var/zeppelin/zeppelin-distribution/target/*.tar.gz /opt/
RUN tar xvf /opt/*.tar.gz --directory=/opt
RUN rm /opt/*.tar.gz

RUN pip3 install --upgrade matplotlib seaborn jupyter grpcio
RUN ln -s /opt/zeppelin* /opt/zeppelin
WORKDIR /opt/zeppelin
RUN cp conf/shiro.ini.template conf/shiro.ini
RUN sed -i 's/\#admin = password1/xp = vlab4xp/' conf/shiro.ini
RUN sed -i 's/user1 = password2, role1, role2//' conf/shiro.ini
RUN sed -i 's/user2 = password3, role3//' conf/shiro.ini
RUN sed -i 's/user3 = password4, role2//' conf/shiro.ini
RUN cp conf/zeppelin-site.xml.template conf/zeppelin-site.xml
RUN sed -i '/<name>zeppelin.anonymous.allowed<\/name>/{n;s/<value>.*<\/value>/<value>false<\/value>/;}' conf/zeppelin-site.xml
