FROM maven:3.8.1-openjdk-16 AS builder
ADD . /app/
WORKDIR /app/
RUN mvn package

FROM openjdk:17
COPY --from=builder /app/target/sample-service-0.0.1-SNAPSHOT.jar /app/
WORKDIR /app/
RUN adduser joe
RUN chmod a+r /app/*.jar
USER joe
CMD ["/usr/java/openjdk-17/bin/java", "-jar", "sample-service-0.0.1-SNAPSHOT.jar"]
