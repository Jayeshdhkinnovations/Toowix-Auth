<#import "toowix-layout.ftl" as toowix>
<@toowix.page heading="Forgot password?" subtitle="Enter your email and we'll send you a link to reset your password." storyHeading="Reset your" storyAccent="password" storyText="No worries, it happens.<br>Enter your email to get started.">
<form id="kc-reset-password-form" class="toowix-form" action="${url.loginAction}" method="post">
  <label for="username">Email or company username</label>
  <div class="toowix-input-wrap"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3.5 5.5h17v13h-17zM4 6l8 6 8-6"/></svg><input id="username" name="username" value="${auth.attemptedUsername!''}" type="text" autocomplete="username" autofocus placeholder="you@toowix.com"></div>
  <button id="kc-reset-password-submit" class="toowix-action" type="submit">Send link <span aria-hidden="true">&rarr;</span></button>
</form>
<a class="toowix-back" href="${url.loginUrl}">Back to sign in</a>
</@toowix.page>
