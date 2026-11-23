<#macro emailLayout>
<!DOCTYPE html>
<html lang="${locale.language}" dir="${(ltr)?then('ltr','rtl')}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Toowix</title>
<style>
  body { margin: 0; padding: 0; background: #f3f2fb; }
  p { margin: 0 0 16px; color: #0b163c; font: 15px/1.6 Arial, Helvetica, sans-serif; }
  a { color: #5d12ec; font-weight: 600; text-decoration: underline; }
  b { color: #0b163c; }
</style>
</head>
<body style="margin:0; padding:0; background:#f3f2fb;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f3f2fb; padding: 32px 16px;">
<tr>
<td align="center">
<table role="presentation" width="560" cellpadding="0" cellspacing="0" style="max-width:560px; width:100%; background:#ffffff; border:1px solid #e3e6f2; border-radius:14px; overflow:hidden;">

<tr>
<td style="padding: 32px 36px 20px;">
<table role="presentation" cellpadding="0" cellspacing="0">
<tr>
<td style="width:36px; height:36px; background:#5d12ec; border-radius:9px; text-align:center; vertical-align:middle; font:bold 18px Arial, Helvetica, sans-serif; color:#ffffff;">T</td>
<td style="padding-left:12px; font:bold 20px Arial, Helvetica, sans-serif; color:#0b163c; vertical-align:middle;">Toowix</td>
</tr>
</table>
</td>
</tr>

<tr>
<td style="padding: 0 36px 8px; border-top:1px solid #e3e6f2;"></td>
</tr>

<tr>
<td style="padding: 24px 36px 32px;">
<#nested>
</td>
</tr>

<tr>
<td style="padding: 20px 36px 28px; border-top:1px solid #e3e6f2;">
<p style="margin:0; font:13px/1.5 Arial, Helvetica, sans-serif; color:#7280a5;">This is an automated message from Toowix. If you were not expecting this email, you can safely ignore it.</p>
</td>
</tr>

</table>
</td>
</tr>
</table>
</body>
</html>
</#macro>
