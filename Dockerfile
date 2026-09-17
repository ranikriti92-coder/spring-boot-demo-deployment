# ---- Stage 1: Build the application with Maven ----
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /workspace

# Copy only the pom first so Docker can cache dependency downloads
COPY pom.xml .
RUN mvn -q dependency:go-offline || true

# Now copy the source and build the real jar
COPY src src
RUN mvn -q clean package -DskipTests

# ---- Stage 2: Run it in a small, production-style image ----
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# OpenShift runs containers as a random non-root UID by default.
# This makes sure our app owns its own folder and doesn't assume root.
RUN useradd -r -u 1001 appuser
COPY --from=build /workspace/target/demo.jar /app/app.jar
RUN chown -R 1001:0 /app && chmod -R g=u /app
USER 1001

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
