# Stage 1: compile the Toowix email OTP authenticator SPI into a JAR.
FROM maven:3.9-eclipse-temurin-21 AS spi-build
WORKDIR /build
COPY email-otp-spi/pom.xml ./pom.xml
COPY email-otp-spi/src ./src
RUN mvn -B -q package

# Stage 2: the official Keycloak image with the Toowix theme and the SPI.
FROM quay.io/keycloak/keycloak:26.7.4

COPY themes/toowix /opt/keycloak/themes/toowix
COPY --from=spi-build /build/target/toowix-email-otp.jar /opt/keycloak/providers/toowix-email-otp.jar

# Keycloak only loads new providers after a build step.
RUN /opt/keycloak/bin/kc.sh build
