<#-- Toowix presentation of Keycloak's built-in TOTP enrolment. The server still
    creates and verifies the shared secret; this template only renders its form. -->
<#import "toowix-layout.ftl" as toowix>
<@toowix.page heading="Set up authenticator" subtitle="Add Toowix to an authenticator app, then confirm the code it generates." storyHeading="Make your account" storyAccent="more secure" storyText="Use an authenticator app for<br>a fast, secure sign-in.">
<section id="toowix-totp-scan" class="toowix-totp-panel" aria-labelledby="kc-page-title"<#if messagesPerField.existsError('totp','userLabel')> hidden</#if>>
<ol class="toowix-setup-steps">
  <li class="toowix-setup-step">
    <strong>Open an authenticator app</strong>
    <ul class="toowix-supported-apps"><#list totp.supportedApplications as app><li>${msg(app)}</li></#list></ul>
  </li>
  <#if mode?? && mode = "manual">
    <li class="toowix-setup-step">
      <strong>Enter this setup key</strong>
      <code id="kc-totp-secret-key" class="toowix-secret">${totp.totpSecretEncoded}</code>
      <a class="toowix-setup-link" href="${totp.qrUrl}" id="mode-barcode">Scan a QR code instead</a>
    </li>
    <li class="toowix-setup-step">
      <strong>Use these settings</strong>
      <ul class="toowix-policy">
        <li>${msg("loginTotpType")}: ${msg("loginTotp." + totp.policy.type)}</li>
        <li>${msg("loginTotpAlgorithm")}: ${totp.policy.getAlgorithmKey()}</li>
        <li>${msg("loginTotpDigits")}: ${totp.policy.digits}</li>
        <#if totp.policy.type = "totp"><li>${msg("loginTotpInterval")}: ${totp.policy.period}</li><#elseif totp.policy.type = "hotp"><li>${msg("loginTotpCounter")}: ${totp.policy.initialCounter}</li></#if>
      </ul>
    </li>
  <#else>
    <li class="toowix-setup-step">
      <strong>Scan the QR code</strong><br>
      Use your app to scan this code. <img id="kc-totp-secret-qr-code" class="toowix-qr" src="data:image/png;base64, ${totp.totpSecretQrCode}" alt="QR code for adding Toowix to your authenticator app">
      <a class="toowix-setup-link" href="${totp.manualUrl}" id="mode-manual">Can't scan the code? Use a setup key</a>
    </li>
  </#if>
</ol>
<button id="toowix-totp-next" class="toowix-action" type="button">I've scanned it <span aria-hidden="true">&rarr;</span></button>
</section>

<form action="${url.loginAction}" class="toowix-form toowix-totp-panel" id="kc-totp-settings-form" method="post" novalidate<#if !messagesPerField.existsError('totp','userLabel')> hidden</#if>>
  <p class="toowix-step">Step 2 of 2</p>
  <p class="toowix-instruction">Enter the current six-digit code from your authenticator app to finish setup.</p>
  <label for="totp">Authenticator code</label>
  <input id="totp" class="toowix-plain-input" name="totp" type="text" autocomplete="one-time-code" inputmode="numeric" pattern="[0-9]{6}" maxlength="6" required autofocus aria-invalid="<#if messagesPerField.existsError('totp')>true<#else>false</#if>" placeholder="123456">
  <#if messagesPerField.existsError('totp')><p class="toowix-message" id="input-error-otp-code" role="alert">${messagesPerField.get('totp')}</p></#if>
  <label for="userLabel">Device name<#if totp.otpCredentials?size gte 1> (required)</#if></label>
  <input id="userLabel" class="toowix-plain-input" name="userLabel" type="text" autocomplete="off" aria-invalid="<#if messagesPerField.existsError('userLabel')>true<#else>false</#if>" placeholder="My authenticator">
  <#if messagesPerField.existsError('userLabel')><p class="toowix-message" id="input-error-otp-label" role="alert">${messagesPerField.get('userLabel')}</p></#if>
  <input type="hidden" id="totpSecret" name="totpSecret" value="${totp.totpSecret}">
  <#if mode??><input type="hidden" id="mode" name="mode" value="${mode}"></#if>
  <#if isAppInitiatedAction??><button class="toowix-back-button" id="cancelTOTPBtn" name="cancel-aia" type="submit" value="true" formnovalidate>Cancel</button></#if>
  <button id="saveTOTPBtn" class="toowix-action" type="submit">Confirm setup <span aria-hidden="true">&rarr;</span></button>
</form>
<script>
  (() => {
    const scan = document.getElementById('toowix-totp-scan');
    const form = document.getElementById('kc-totp-settings-form');
    const next = document.getElementById('toowix-totp-next');
    const code = document.getElementById('totp');
    if (!scan || !form || !next || !code) return;
    next.addEventListener('click', () => { scan.hidden = true; form.hidden = false; code.focus(); });
  })();
</script>
</@toowix.page>
