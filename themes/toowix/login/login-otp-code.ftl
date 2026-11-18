<#import "toowix-layout.ftl" as toowix>
<@toowix.page heading="Enter your code" subtitle="Enter the 6-digit code from your authenticator app." storyHeading="Verify" storyAccent="it's you" storyText="Enter the code shown in<br>your authenticator app.">
<p class="toowix-step">Step 2 of 2</p>
<form id="kc-totp-form" class="toowix-form" action="${url.loginAction}" method="post" autocomplete="off" novalidate>
  <label for="totpCode">Authenticator code</label>
  <input id="totpCode" class="toowix-plain-input" name="totpCode" type="text" inputmode="numeric" pattern="[0-9]{6}" maxlength="6" autocomplete="one-time-code" autofocus required placeholder="123456">
  <input type="hidden" name="emailOtpStep" value="totp">
  <button id="toowix-next" class="toowix-action" type="submit">Verify <span aria-hidden="true">&rarr;</span></button>
</form>
<form class="toowix-form" action="${url.loginAction}" method="post">
  <input type="hidden" name="emailOtpStep" value="back">
  <button class="toowix-back-button" type="submit" formnovalidate>&larr; Choose another method</button>
</form>
</@toowix.page>
