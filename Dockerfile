FROM maven:3.9-eclipse-temurin-17 AS build

WORKDIR /workspace

COPY pom.xml .
COPY src src

RUN mvn -q clean package -DskipTests

FROM eclipse-temurin:17-jre-jammy

WORKDIR /app

COPY --from=build /workspace/target/*.jar /app/app.jar

RUN chgrp -R 0 /app && chmod -R g=u /app

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]