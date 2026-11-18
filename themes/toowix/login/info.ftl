<#import "toowix-layout.ftl" as toowix>
<@toowix.page heading="All set!" subtitle="Your request has been completed successfully." storyHeading="All" storyAccent="set!" storyText="Your account is ready.<br>Continue securely with Toowix.">
<div class="toowix-success" aria-hidden="true">✓</div><p class="toowix-instruction">${message.summary}</p>
<#if !skipLink??><#if pageRedirectUri?has_content><a class="toowix-action toowix-action-link" href="${pageRedirectUri}">${msg("backToApplication")} <span>&rarr;</span></a><#elseif actionUri?has_content><a class="toowix-action toowix-action-link" href="${actionUri}">${msg("proceedWithAction")} <span>&rarr;</span></a><#elseif (client.baseUrl)?has_content><a class="toowix-action toowix-action-link" href="${client.baseUrl}">${msg("backToApplication")} <span>&rarr;</span></a></#if></#if>
</@toowix.page>
