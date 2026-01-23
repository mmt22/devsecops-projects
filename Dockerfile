# -----------------------------------------------------------------------------
# Stage 1: Build (Standard Maven Build)
# -----------------------------------------------------------------------------
FROM maven:3.9.6-eclipse-temurin-17 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn clean package -DskipTests

# -----------------------------------------------------------------------------
# Stage 2: Run (Chainguard / Wolfi)
# "Wolfi" is designed to be 0-CVE. It rebuilds daily.
# -----------------------------------------------------------------------------
FROM cgr.dev/chainguard/jre:latest

WORKDIR /app

# Copy the JAR
COPY --from=builder /app/target/*.jar app.jar

# Chainguard runs as 'nonroot' (UID 65532) by default.
# The entrypoint is already set to 'java'.
CMD ["-jar", "app.jar"]