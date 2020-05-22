FROM openjdk:8-jdk-alpine
MAINTAINER fengxuechao <fengxuechao.littlefxc@gmail.com>
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 TZ=Asia/Shanghai
RUN mkdir /app /app/config /app/logs
WORKDIR /app
COPY ./* /app/
RUN mv *.jar app.jar
EXPOSE 8080