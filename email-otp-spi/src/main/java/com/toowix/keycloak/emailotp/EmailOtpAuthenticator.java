package com.toowix.keycloak.emailotp;

import jakarta.ws.rs.core.MultivaluedMap;
import jakarta.ws.rs.core.Response;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Locale;
import java.util.regex.Pattern;
import org.jboss.logging.Logger;
import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.AuthenticationFlowError;
import org.keycloak.authentication.Authenticator;
import org.keycloak.credential.CredentialProvider;
import org.keycloak.credential.OTPCredentialProvider;
import org.keycloak.credential.OTPCredentialProviderFactory;
import org.keycloak.common.Version;
import org.keycloak.email.EmailException;
import org.keycloak.email.EmailSenderProvider;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserCredentialModel;
import org.keycloak.models.UserModel;
import org.keycloak.models.credential.OTPCredentialModel;
import org.keycloak.urls.UrlType;

/**
 * Second-factor step shown after the password. The user chooses either the authenticator app
 * (TOTP) or a one-time code emailed to their recovery address.
 *
 * <p>Email codes are stored only as a salted SHA-256 hash in the authentication session, expire
 * after {@link #CODE_TTL}, and are rejected after {@link #MAX_ATTEMPTS} wrong guesses. If the
 * user has no {@value #RECOVERY_EMAIL_ATTRIBUTE} attribute yet, they are asked for one first and
 * it is saved to their profile.
 */
public class EmailOtpAuthenticator implements Authenticator {

    private static final Logger LOG = Logger.getLogger(EmailOtpAuthenticator.class);

    static final String RECOVERY_EMAIL_ATTRIBUTE = "recovery_email";
    /** Per-user switch for the optional second factor. Set to true in Keycloak's user attributes. */
    static final String TWO_FACTOR_ENABLED_ATTRIBUTE = "toowix_2fa_enabled";

    static final String STEP_FIELD = "emailOtpStep";
    static final String METHOD_FIELD = "twoFactorMethod";
    static final String CODE_FIELD = "emailOtpCode";
    static final String TOTP_FIELD = "totpCode";
    static final String RECOVERY_FIELD = "recoveryEmail";

    static final String STEP_METHOD = "method";
    static final String STEP_RECOVERY = "recovery";
    static final String STEP_RESEND = "resend";
    static final String STEP_CODE = "code";
    static final String STEP_TOTP = "totp";
    static final String STEP_BACK = "back";

    static final String METHOD_TOTP = "totp";
    static final String METHOD_EMAIL = "email";

    static final String NOTE_METHOD = "toowix_2fa_method";
    static final String NOTE_HASH = "toowix_email_otp_hash";
    static final String NOTE_SALT = "toowix_email_otp_salt";
    static final String NOTE_EXPIRES = "toowix_email_otp_expires";
    static final String NOTE_ATTEMPTS = "toowix_email_otp_attempts";
    static final String NOTE_SENDS = "toowix_email_otp_sends";

    static final java.time.Duration CODE_TTL = java.time.Duration.ofMinutes(5);
    static final int MAX_ATTEMPTS = 5;
    static final int MAX_SENDS = 5;

    private static final Pattern CODE_PATTERN = Pattern.compile("\\d{6}");
    private static final Pattern EMAIL_PATTERN = Pattern.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$");
    private static final SecureRandom RANDOM = new SecureRandom();

    static final String FORM_METHOD = "login-2fa-method.ftl";
    static final String FORM_TOTP = "login-otp-code.ftl";
    static final String FORM_CODE = "login-email-otp.ftl";
    static final String FORM_RECOVERY = "login-recovery-email.ftl";

    @Override
    public void authenticate(AuthenticationFlowContext context) {
        if (context.getUser() == null) {
            context.failure(AuthenticationFlowError.UNKNOWN_USER);
            return;
        }
        // The execution can be REQUIRED without forcing MFA for every account.
        // A user opts in explicitly, or is already enrolled in Keycloak TOTP.
        if (!isTwoFactorEnabled(context.getSession(), context.getRealm(), context.getUser())) {
            context.success();
            return;
        }
        context.challenge(methodForm(context, null));
    }

    @Override
    public void action(AuthenticationFlowContext context) {
        UserModel user = context.getUser();
        if (user == null) {
            context.failure(AuthenticationFlowError.UNKNOWN_USER);
            return;
        }
        MultivaluedMap<String, String> form = context.getHttpRequest().getDecodedFormParameters();
        String step = form.getFirst(STEP_FIELD);

        if (STEP_METHOD.equals(step)) {
            chooseMethod(context, user, form.getFirst(METHOD_FIELD));
        } else if (STEP_BACK.equals(step)) {
            clearCode(context);
            context.challenge(methodForm(context, null));
        } else if (STEP_TOTP.equals(step)) {
            verifyTotp(context, user, form.getFirst(TOTP_FIELD));
        } else if (STEP_RECOVERY.equals(step)) {
            saveRecoveryEmail(context, user, form.getFirst(RECOVERY_FIELD));
        } else if (STEP_RESEND.equals(step)) {
            resendCode(context, user);
        } else {
            verifyCode(context, user, form.getFirst(CODE_FIELD));
        }
    }

    private void chooseMethod(AuthenticationFlowContext context, UserModel user, String method) {
        if (METHOD_TOTP.equals(method)) {
            context.getAuthenticationSession().setAuthNote(NOTE_METHOD, METHOD_TOTP);
            if (totpProvider(context.getSession()).isConfiguredFor(context.getRealm(), user)) {
                context.challenge(totpForm(context, null));
            } else {
                // No authenticator app yet: finish this step and let Keycloak run the QR enrollment.
                context.getAuthenticationSession().addRequiredAction(UserModel.RequiredAction.CONFIGURE_TOTP);
                context.success();
            }
        } else if (METHOD_EMAIL.equals(method)) {
            context.getAuthenticationSession().setAuthNote(NOTE_METHOD, METHOD_EMAIL);
            String recoveryEmail = recoveryEmailOf(user);
            if (recoveryEmail == null) {
                context.challenge(recoveryForm(context, null));
            } else {
                sendCode(context, recoveryEmail);
            }
        } else {
            context.challenge(methodForm(context, "emailOtpChooseMethod"));
        }
    }

    private void verifyTotp(AuthenticationFlowContext context, UserModel user, String rawCode) {
        if (intNote(context, NOTE_ATTEMPTS) >= MAX_ATTEMPTS) {
            context.failureChallenge(AuthenticationFlowError.INVALID_CREDENTIALS,
                    totpForm(context, "emailOtpTooManyAttempts"));
            return;
        }
        String code = rawCode == null ? "" : rawCode.replace(" ", "").trim();
        if (!CODE_PATTERN.matcher(code).matches()) {
            incrementAttempts(context);
            context.failureChallenge(AuthenticationFlowError.INVALID_CREDENTIALS,
                    totpForm(context, "emailOtpInvalidCode"));
            return;
        }

        OTPCredentialProvider provider = totpProvider(context.getSession());
        OTPCredentialModel credential = provider.getDefaultCredential(context.getSession(), context.getRealm(), user);
        boolean valid = credential != null && user.credentialManager().isValid(
                new UserCredentialModel(credential.getId(), provider.getType(), code));
        if (valid) {
            clearCode(context);
            context.success();
            return;
        }
        incrementAttempts(context);
        context.failureChallenge(AuthenticationFlowError.INVALID_CREDENTIALS,
                totpForm(context, "emailOtpInvalidTotp"));
    }

    private void saveRecoveryEmail(AuthenticationFlowContext context, UserModel user, String rawEmail) {
        String email = rawEmail == null ? "" : rawEmail.trim().toLowerCase(Locale.ROOT);
        if (!EMAIL_PATTERN.matcher(email).matches()) {
            context.failureChallenge(AuthenticationFlowError.INVALID_CREDENTIALS,
                    recoveryForm(context, "emailOtpInvalidRecoveryEmail"));
            return;
        }
        user.setSingleAttribute(RECOVERY_EMAIL_ATTRIBUTE, email);
        sendCode(context, email);
    }

    private void resendCode(AuthenticationFlowContext context, UserModel user) {
        String recoveryEmail = recoveryEmailOf(user);
        if (recoveryEmail == null) {
            context.challenge(recoveryForm(context, null));
            return;
        }
        int sends = intNote(context, NOTE_SENDS);
        if (sends >= MAX_SENDS) {
            context.failureChallenge(AuthenticationFlowError.INVALID_CREDENTIALS,
                    codeForm(context, recoveryEmail, "emailOtpTooManySends"));
            return;
        }
        sendCode(context, recoveryEmail);
    }

    private void verifyCode(AuthenticationFlowContext context, UserModel user, String rawCode) {
        String hash = context.getAuthenticationSession().getAuthNote(NOTE_HASH);
        String salt = context.getAuthenticationSession().getAuthNote(NOTE_SALT);
        String expires = context.getAuthenticationSession().getAuthNote(NOTE_EXPIRES);
        String recoveryEmail = recoveryEmailOf(user);

        if (hash == null || salt == null || expires == null) {
            // Nothing was sent in this session yet, so send the first code.
            authenticate(context);
            return;
        }
        if (recoveryEmail == null) {
            context.challenge(recoveryForm(context, null));
            return;
        }
        if (Instant.now().isAfter(Instant.parse(expires))) {
            clearCode(context);
            context.failureChallenge(AuthenticationFlowError.EXPIRED_CODE,
                    codeForm(context, recoveryEmail, "emailOtpExpired"));
            return;
        }
        if (intNote(context, NOTE_ATTEMPTS) >= MAX_ATTEMPTS) {
            clearCode(context);
            context.failureChallenge(AuthenticationFlowError.INVALID_CREDENTIALS,
                    codeForm(context, recoveryEmail, "emailOtpTooManyAttempts"));
            return;
        }

        String code = rawCode == null ? "" : rawCode.replace(" ", "").trim();
        if (!CODE_PATTERN.matcher(code).matches()) {
            incrementAttempts(context);
            context.failureChallenge(AuthenticationFlowError.INVALID_CREDENTIALS,
                    codeForm(context, recoveryEmail, "emailOtpInvalidCode"));
            return;
        }

        byte[] expected = HexFormat.of().parseHex(hash);
        byte[] actual = digest(salt, code);
        if (MessageDigest.isEqual(expected, actual)) {
            clearCode(context);
            context.success();
            return;
        }

        incrementAttempts(context);
        context.failureChallenge(AuthenticationFlowError.INVALID_CREDENTIALS,
                codeForm(context, recoveryEmail, "emailOtpInvalidCode"));
    }

    private void sendCode(AuthenticationFlowContext context, String recoveryEmail) {
        String code = String.format(Locale.ROOT, "%06d", RANDOM.nextInt(1_000_000));
        String salt = newSalt();

        KeycloakSession session = context.getSession();
        RealmModel realm = context.getRealm();
        try {
            session.getProvider(EmailSenderProvider.class).send(
                    realm.getSmtpConfig(),
                    recoveryEmail,
                    "Your Toowix verification code",
                    textBody(code),
                    htmlBody(code, logoUrl(session)));
        } catch (EmailException e) {
            LOG.warnf(e, "Could not send Toowix email OTP for realm %s", realm.getName());
            context.challenge(codeForm(context, recoveryEmail, "emailOtpSendFailed"));
            return;
        }

        context.getAuthenticationSession().setAuthNote(NOTE_METHOD, METHOD_EMAIL);
        context.getAuthenticationSession().setAuthNote(NOTE_SALT, salt);
        context.getAuthenticationSession().setAuthNote(NOTE_HASH, HexFormat.of().formatHex(digest(salt, code)));
        context.getAuthenticationSession().setAuthNote(NOTE_EXPIRES, Instant.now().plus(CODE_TTL).toString());
        context.getAuthenticationSession().setAuthNote(NOTE_ATTEMPTS, "0");
        context.getAuthenticationSession().setAuthNote(NOTE_SENDS, String.valueOf(intNote(context, NOTE_SENDS) + 1));

        context.challenge(codeForm(context, recoveryEmail, null));
    }

    private Response methodForm(AuthenticationFlowContext context, String errorKey) {
        var form = context.form();
        String recoveryEmail = recoveryEmailOf(context.getUser());
        form.setAttribute("maskedEmail", recoveryEmail == null ? null : maskEmail(recoveryEmail));
        form.setAttribute("hasTotp", totpProvider(context.getSession()).isConfiguredFor(context.getRealm(), context.getUser()));
        if (errorKey != null) {
            form.setError(errorKey);
        }
        return form.createForm(FORM_METHOD);
    }

    private Response totpForm(AuthenticationFlowContext context, String errorKey) {
        var form = context.form();
        if (errorKey != null) {
            form.setError(errorKey);
        }
        return form.createForm(FORM_TOTP);
    }

    private Response codeForm(AuthenticationFlowContext context, String recoveryEmail, String errorKey) {
        var form = context.form().setAttribute("maskedEmail", maskEmail(recoveryEmail));
        if (errorKey != null) {
            form.setError(errorKey);
        }
        return form.createForm(FORM_CODE);
    }

    private Response recoveryForm(AuthenticationFlowContext context, String errorKey) {
        var form = context.form();
        if (errorKey != null) {
            form.setError(errorKey);
        }
        return form.createForm(FORM_RECOVERY);
    }

    private static OTPCredentialProvider totpProvider(KeycloakSession session) {
        return (OTPCredentialProvider) session.getProvider(CredentialProvider.class, OTPCredentialProviderFactory.PROVIDER_ID);
    }

    private void clearCode(AuthenticationFlowContext context) {
        var notes = context.getAuthenticationSession();
        notes.removeAuthNote(NOTE_HASH);
        notes.removeAuthNote(NOTE_SALT);
        notes.removeAuthNote(NOTE_EXPIRES);
        notes.removeAuthNote(NOTE_ATTEMPTS);
    }

    private void incrementAttempts(AuthenticationFlowContext context) {
        context.getAuthenticationSession().setAuthNote(NOTE_ATTEMPTS, String.valueOf(intNote(context, NOTE_ATTEMPTS) + 1));
    }

    private int intNote(AuthenticationFlowContext context, String name) {
        String value = context.getAuthenticationSession().getAuthNote(name);
        try {
            return value == null ? 0 : Integer.parseInt(value);
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    private static String recoveryEmailOf(UserModel user) {
        if (user == null) {
            return null;
        }
        String value = user.getFirstAttribute(RECOVERY_EMAIL_ATTRIBUTE);
        return value == null || value.isBlank() ? null : value.trim();
    }

    private static boolean isTwoFactorEnabled(KeycloakSession session, RealmModel realm, UserModel user) {
        if (user == null) {
            return false;
        }
        String enabled = user.getFirstAttribute(TWO_FACTOR_ENABLED_ATTRIBUTE);
        return "true".equalsIgnoreCase(enabled) || totpProvider(session).isConfiguredFor(realm, user);
    }

    static String maskEmail(String email) {
        if (email == null) {
            return "";
        }
        int at = email.indexOf('@');
        if (at <= 0) {
            return "***";
        }
        String local = email.substring(0, at);
        String masked = local.length() <= 2
                ? local.charAt(0) + "***"
                : local.charAt(0) + "***" + local.charAt(local.length() - 1);
        return masked + email.substring(at);
    }

    private static String newSalt() {
        byte[] bytes = new byte[16];
        RANDOM.nextBytes(bytes);
        return Base64.getEncoder().encodeToString(bytes);
    }

    private static byte[] digest(String salt, String code) {
        try {
            MessageDigest sha = MessageDigest.getInstance("SHA-256");
            return sha.digest((salt + ":" + code).getBytes(StandardCharsets.UTF_8));
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 is not available", e);
        }
    }

    private static String textBody(String code) {
        return "TOOWIX\n------\n\n"
                + "Your verification code is: " + code + "\n\n"
                + "It expires in " + CODE_TTL.toMinutes() + " minutes. "
                + "If you did not try to sign in, ignore this email and consider changing your password.\n\n"
                + "--\n"
                + "This is an automated message from Toowix. If you were not expecting this email, you can safely ignore it.";
    }

    // Static resource path Keycloak serves theme files under. Version.RESOURCES_VERSION is a
    // constant for a given Keycloak distribution (not a per-rebuild hash), so this stays correct
    // across image rebuilds and only needs revisiting on a Keycloak version upgrade.
    private static String logoUrl(KeycloakSession session) {
        String base = session.getContext().getUri(UrlType.FRONTEND).getBaseUri().toString();
        if (!base.endsWith("/")) {
            base += "/";
        }
        return base + "resources/" + Version.RESOURCES_VERSION + "/email/toowix/img/brand-mark.png";
    }

    // Built independently of the theme system's shared template.ftl wrapper (this authenticator
    // calls EmailSenderProvider directly, not Keycloak's FreeMarker email templates), so the same
    // header/footer chrome as themes/toowix/email/html/template.ftl is reproduced inline here.
    private static String htmlBody(String code, String logoUrl) {
        return "<!DOCTYPE html><html><body style=\"margin:0;padding:0;background:#f3f2fb;\">"
                + "<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" style=\"background:#f3f2fb;padding:32px 16px;\"><tr><td align=\"center\">"
                + "<table role=\"presentation\" width=\"560\" cellpadding=\"0\" cellspacing=\"0\" style=\"max-width:560px;width:100%;background:#ffffff;border:1px solid #e3e6f2;border-radius:14px;overflow:hidden;\">"
                + "<tr><td style=\"padding:32px 36px 20px;\">"
                + "<table role=\"presentation\" cellpadding=\"0\" cellspacing=\"0\"><tr>"
                + "<td style=\"width:36px;height:36px;vertical-align:middle;\"><img src=\"" + logoUrl + "\" alt=\"Toowix\" width=\"36\" height=\"36\" style=\"display:block;border:0;\"></td>"
                + "<td style=\"padding-left:12px;font:bold 20px Arial, Helvetica, sans-serif;color:#0b163c;vertical-align:middle;\">Toowix</td>"
                + "</tr></table></td></tr>"
                + "<tr><td style=\"padding:0 36px 8px;border-top:1px solid #e3e6f2;\"></td></tr>"
                + "<tr><td style=\"padding:24px 36px 32px;font:15px/1.6 Arial, Helvetica, sans-serif;color:#0b163c;\">"
                + "<p style=\"margin:0 0 16px;\">Your verification code is:</p>"
                + "<p style=\"margin:0 0 16px;font-size:28px;font-weight:700;letter-spacing:4px;color:#5d12ec;\">" + code + "</p>"
                + "<p style=\"margin:0;\">It expires in " + CODE_TTL.toMinutes() + " minutes. "
                + "If you did not try to sign in, ignore this email and consider changing your password.</p>"
                + "</td></tr>"
                + "<tr><td style=\"padding:20px 36px 28px;border-top:1px solid #e3e6f2;\">"
                + "<p style=\"margin:0;font:13px/1.5 Arial, Helvetica, sans-serif;color:#7280a5;\">This is an automated message from Toowix. If you were not expecting this email, you can safely ignore it.</p>"
                + "</td></tr>"
                + "</table></td></tr></table></body></html>";
    }

    @Override
    public boolean requiresUser() {
        return true;
    }

    @Override
    public boolean configuredFor(KeycloakSession session, RealmModel realm, UserModel user) {
        return isTwoFactorEnabled(session, realm, user);
    }

    @Override
    public void setRequiredActions(KeycloakSession session, RealmModel realm, UserModel user) {
        // Enrollment is requested from the method choice when needed.
    }

    @Override
    public void close() {
        // Stateless.
    }
}
