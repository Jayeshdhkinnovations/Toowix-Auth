<#import "toowix-layout.ftl" as toowix>
<@toowix.page heading="Add a recovery email" subtitle="We'll send your sign-in codes here. You only need to do this once." storyHeading="Secure" storyAccent="your account" storyText="Add a recovery email<br>for verification codes.">
<form id="kc-recovery-email-form" class="toowix-form" action="${url.loginAction}" method="post" autocomplete="off">
  <label for="recoveryEmail">Recovery email</label>
  <input id="recoveryEmail" class="toowix-plain-input" name="recoveryEmail" type="email" autocomplete="email" autofocus required placeholder="you@example.com">
  <input type="hidden" name="emailOtpStep" value="recovery">
  <button id="toowix-next" class="toowix-action" type="submit">Send code <span aria-hidden="true">&rarr;</span></button>
</form>
<form class="toowix-form" action="${url.loginAction}" method="post">
  <input type="hidden" name="emailOtpStep" value="back">
  <button class="toowix-back-button" type="submit" formnovalidate>&larr; Choose another method</button>
</form>
</@toowix.page>
