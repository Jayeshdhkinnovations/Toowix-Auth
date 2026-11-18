<#import "toowix-layout.ftl" as toowix>
<@toowix.page heading="Two-factor authentication" subtitle="Choose a verification method to complete sign in." storyHeading="Two-factor" storyAccent="authentication" storyText="Choose how you want to<br>verify it's you.">
<p class="toowix-step">Step 1 of 2</p>
<form id="kc-2fa-method-form" class="toowix-form" action="${url.loginAction}" method="post" novalidate>
  <fieldset class="toowix-method-list">
    <legend class="toowix-sr-only">Verification method</legend>
    <label class="toowix-method">
      <span class="toowix-method-icon" aria-hidden="true"><svg viewBox="0 0 24 24"><rect x="7" y="3" width="10" height="18" rx="2"/><path d="M11 18h2"/></svg></span>
      <span class="toowix-method-body">
        <span class="toowix-method-title">Authenticator app <span class="toowix-badge">Recommended</span></span>
        <span class="toowix-method-desc">Enter the 6-digit code from your authenticator app.</span>
      </span>
      <input type="radio" name="twoFactorMethod" value="totp" checked>
    </label>
    <label class="toowix-method">
      <span class="toowix-method-icon" aria-hidden="true"><svg viewBox="0 0 24 24"><rect x="3" y="5.5" width="18" height="13" rx="1.5"/><path d="M3.5 6l8.5 6.5L20.5 6"/></svg></span>
      <span class="toowix-method-body">
        <span class="toowix-method-title">Email verification code</span>
        <span class="toowix-method-desc"><#if maskedEmail?has_content>Send a temporary 6-digit code to your recovery email (${maskedEmail}).<#else>Send a temporary 6-digit code to your recovery email. You'll add the address next.</#if></span>
      </span>
      <input type="radio" name="twoFactorMethod" value="email">
    </label>
  </fieldset>
  <input type="hidden" name="emailOtpStep" value="method">
  <button id="toowix-next" class="toowix-action" type="submit">Continue <span aria-hidden="true">&rarr;</span></button>
</form>
<p class="toowix-instruction toowix-center"><a class="toowix-back" href="${url.loginRestartFlowUrl}">&larr; Back to sign in</a></p>
</@toowix.page>
