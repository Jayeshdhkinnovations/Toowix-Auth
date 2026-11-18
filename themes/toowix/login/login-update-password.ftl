<#import "toowix-layout.ftl" as toowix>
<@toowix.page heading="Create new password" subtitle="Your new password must be different from your previous one." storyHeading="Set a new" storyAccent="password" storyText="Choose a strong password<br>to keep your account secure.">
<form id="kc-passwd-update-form" class="toowix-form" action="${url.loginAction}" method="post" novalidate>
  <label for="password-new">New password</label><input id="password-new" class="toowix-plain-input" name="password-new" type="password" autocomplete="new-password" autofocus required>
  <label for="password-confirm">Confirm new password</label><input id="password-confirm" class="toowix-plain-input" name="password-confirm" type="password" autocomplete="new-password" required>
  <button id="kc-submit" class="toowix-action" name="login" type="submit">Continue <span aria-hidden="true">&rarr;</span></button>
</form>
</@toowix.page>
