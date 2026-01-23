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
# Stage 2: Run (Hardened / Distroless)
# Uses Google's Distroless image (Debian 12 based).
# Contains ZERO OS tools (no shell, no apt, no ssh).
# -----------------------------------------------------------------------------
FROM gcr.io/distroless/java17-debian12:nonroot

WORKDIR /app

# Copy the JAR and assign it to the built-in 'nonroot' user
COPY --from=builder --chown=nonroot:nonroot /app/target/*.jar app.jar

# Explicitly use the nonroot user (UID 65532)
USER nonroot:nonroot

EXPOSE 8080

# Distroless sets the entrypoint to 'java' automatically.
# We just pass the arguments here.
CMD ["-jar", "app.jar"]