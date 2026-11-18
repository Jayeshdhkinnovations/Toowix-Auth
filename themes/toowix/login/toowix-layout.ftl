<#macro page heading subtitle storyHeading storyAccent storyText>
<!doctype html>
<html lang="${lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${heading}</title><link rel="icon" type="image/svg+xml" href="${url.resourcesPath}/img/brand-mark.svg"><#list properties.styles?split(' ') as style><link href="${url.resourcesPath}/${style}" rel="stylesheet"></#list></head>
<body class="toowix-page"><main class="toowix-shell">
<section class="toowix-story" aria-label="Toowix"><img class="toowix-mark" src="${url.resourcesPath}/img/brand-mark.svg" alt="Toowix"><div class="toowix-story-copy"><h1>${storyHeading}<br><span>${storyAccent}</span></h1><p>${storyText?no_esc}</p></div><div class="toowix-waves" aria-hidden="true"></div><p class="toowix-values">PEOPLE&nbsp;&nbsp;&bull;&nbsp;&nbsp; IDEAS&nbsp;&nbsp;&bull;&nbsp;&nbsp; IMPACT</p></section>
<section class="toowix-login"><div class="toowix-login-content"><header><h2>${heading}</h2><p>${subtitle}</p></header><#if message?has_content><div class="toowix-message ${message.type!}" role="alert">${kcSanitize(message.summary)?no_esc}</div></#if><#nested></div></section>
</main></body></html>
</#macro>
