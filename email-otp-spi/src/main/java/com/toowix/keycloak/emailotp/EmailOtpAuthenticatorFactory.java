package com.toowix.keycloak.emailotp;

import java.util.Collections;
import java.util.List;
import org.keycloak.Config;
import org.keycloak.authentication.Authenticator;
import org.keycloak.authentication.AuthenticatorFactory;
import org.keycloak.models.AuthenticationExecutionModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.KeycloakSessionFactory;
import org.keycloak.provider.ProviderConfigProperty;

/** Registers the Toowix email OTP step so it appears in the Authentication flow editor. */
public class EmailOtpAuthenticatorFactory implements AuthenticatorFactory {

    public static final String PROVIDER_ID = "toowix-email-otp";

    private static final EmailOtpAuthenticator SINGLETON = new EmailOtpAuthenticator();

    private static final AuthenticationExecutionModel.Requirement[] REQUIREMENTS = {
        AuthenticationExecutionModel.Requirement.REQUIRED,
        AuthenticationExecutionModel.Requirement.ALTERNATIVE,
        AuthenticationExecutionModel.Requirement.DISABLED
    };

    @Override
    public String getId() {
        return PROVIDER_ID;
    }

    @Override
    public Authenticator create(KeycloakSession session) {
        return SINGLETON;
    }

    @Override
    public void init(Config.Scope config) {
        // No configuration.
    }

    @Override
    public void postInit(KeycloakSessionFactory factory) {
        // Nothing to initialise.
    }

    @Override
    public void close() {
        // Stateless.
    }

    @Override
    public String getDisplayType() {
        return "Toowix Email OTP";
    }

    @Override
    public String getReferenceCategory() {
        return "otp";
    }

    @Override
    public boolean isConfigurable() {
        return false;
    }

    @Override
    public AuthenticationExecutionModel.Requirement[] getRequirementChoices() {
        return REQUIREMENTS;
    }

    @Override
    public boolean isUserSetupAllowed() {
        return false;
    }

    @Override
    public String getHelpText() {
        return "Sends a one-time 6-digit code to the user's recovery email and asks for it at sign-in.";
    }

    @Override
    public List<ProviderConfigProperty> getConfigProperties() {
        return Collections.emptyList();
    }
}
