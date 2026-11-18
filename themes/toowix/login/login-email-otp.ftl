<#import "toowix-layout.ftl" as toowix>
<@toowix.page heading="Check your recovery email" subtitle="Enter the 6-digit code we sent to your recovery email." storyHeading="Verify" storyAccent="it's you" storyText="We sent a 6-digit code<br>to your recovery email.">
<p class="toowix-step">Step 2 of 2</p>
<p class="toowix-instruction">${msg("emailOtpSentTo", maskedEmail!"")}</p>
<form id="kc-email-otp-form" class="toowix-form" action="${url.loginAction}" method="post" autocomplete="off" novalidate>
  <label for="emailOtpCode">Verification code</label>
  <input id="emailOtpCode" class="toowix-plain-input" name="emailOtpCode" type="text" inputmode="numeric" pattern="[0-9]{6}" maxlength="6" autocomplete="one-time-code" autofocus required placeholder="123456">
  <input type="hidden" name="emailOtpStep" value="code">
  <button id="toowix-next" class="toowix-action" type="submit">Verify <span aria-hidden="true">&rarr;</span></button>
</form>
<form class="toowix-form" action="${url.loginAction}" method="post">
  <input type="hidden" name="emailOtpStep" value="resend">
  <button class="toowix-back-button" type="submit" formnovalidate>Resend code</button>
</form>
<form class="toowix-form" action="${url.loginAction}" method="post">
  <input type="hidden" name="emailOtpStep" value="back">
  <button class="toowix-back-button" type="submit" formnovalidate>&larr; Choose another method</button>
</form>
</@toowix.page>
