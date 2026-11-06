@php
    $app_name = \App\Models\Setting::get_value('app_name');
    if ($app_name == '' || $app_name == null) {
        $app_name = 'CakeZake';
    }
    $support_email = \App\Models\Setting::get_value('support_email') ?: '';
    $support_number = \App\Models\Setting::get_value('support_number') ?: '';
    $theme_color = \App\Models\Setting::get_value('admin_theme_color') ?: '#fc7832';
    $logo = \App\Models\Setting::get_value('logo');
    if ($logo !== '' && $logo !== null):
        $logo_full_path = url('/') . '/storage/' . $logo;
    else:
        $logo_full_path = asset('images/favicon.png');
    endif;
@endphp
<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="x-apple-disable-message-reformatting">
    <title>{{ $app_name }}</title>
    <link rel="shortcut icon" href="{{ $logo_full_path }}">
    <!--[if mso]>
    <noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript>
    <![endif]-->
    <style type="text/css">
        body,
        table,
        td {
            font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif !important;
        }

        body {
            margin: 0;
            padding: 0;
            width: 100% !important;
            background-color: #f2f4f6;
            -webkit-font-smoothing: antialiased;
            -webkit-text-size-adjust: 100%;
        }

        img {
            border: 0;
            outline: none;
            text-decoration: none;
        }

        a {
            color: {{ $theme_color }};
            text-decoration: none;
        }

        @media only screen and (max-width: 620px) {
            .container {
                width: 100% !important;
            }

            .content-pad {
                padding-left: 20px !important;
                padding-right: 20px !important;
            }
        }
    </style>
</head>

<body style="margin:0; padding:0; background-color:#f2f4f6;">
    <!-- preheader (hidden preview text) -->
    <div style="display:none; max-height:0; overflow:hidden; font-size:1px; line-height:1px; color:#f2f4f6;">
        {{ $email_title ?? $app_name }}
    </div>

    <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color:#f2f4f6;">
        <tr>
            <td align="center" style="padding: 32px 12px;">
                <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="600" class="container" style="width:600px; max-width:600px;">

                    <!-- logo -->
                    <tr>
                        <td align="center" style="padding: 0 0 24px 0;">
                            <a href="{{ url('/') }}">
                                <img src="{{ $logo_full_path }}" width="120" alt="{{ $app_name }}" style="display:block; width:120px; max-height:60px; object-fit:contain;" />
                            </a>
                        </td>
                    </tr>

                    <!-- card -->
                    <tr>
                        <td style="background-color:#ffffff; border-radius:10px; border:1px solid #e5e7eb; overflow:hidden;">
                            <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                                <!-- theme color accent bar -->
                                <tr>
                                    <td height="5" style="background-color: {{ $theme_color }}; font-size:5px; line-height:5px;">&nbsp;</td>
                                </tr>
                                <tr>
                                    <td class="content-pad" style="padding: 36px 40px 12px 40px;">
                                        @if (!empty($email_title))
                                            <h1 style="margin:0 0 6px 0; font-size:22px; line-height:30px; color:#1f2937; font-weight:700;">
                                                {{ $email_title }}
                                            </h1>
                                            <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                                                <tr>
                                                    <td width="44" height="3" style="background-color: {{ $theme_color }}; font-size:3px; line-height:3px;">&nbsp;</td>
                                                </tr>
                                            </table>
                                        @else
                                            <h1 style="margin:0 0 6px 0; font-size:22px; line-height:30px; color:#1f2937; font-weight:700;">
                                                Welcome to <span style="color: {{ $theme_color }};">{{ $app_name }}</span>
                                            </h1>
                                        @endif
                                    </td>
                                </tr>
                                <tr>
                                    <td class="content-pad" style="padding: 16px 40px 8px 40px; color:#4b5563; font-size:15px; line-height:24px;">
                                        @yield('content')
                                    </td>
                                </tr>
                                <tr>
                                    <td class="content-pad" style="padding: 20px 40px 36px 40px; color:#4b5563; font-size:15px; line-height:24px;">
                                        Thanks &amp; Regards,<br>
                                        <span style="color:#1f2937; font-weight:600;">{{ $app_name }}</span>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>

                    <!-- footer -->
                    <tr>
                        <td align="center" style="padding: 24px 20px 8px 20px; color:#9ca3af; font-size:13px; line-height:20px;">
                            @if ($support_email !== '' || $support_number !== '')
                                <p style="margin:0 0 6px 0;">
                                    Need help?
                                    @if ($support_email !== '')
                                        <a href="mailto:{{ $support_email }}" style="color: {{ $theme_color }};">{{ $support_email }}</a>
                                    @endif
                                    @if ($support_email !== '' && $support_number !== '')
                                        &nbsp;|&nbsp;
                                    @endif
                                    @if ($support_number !== '')
                                        <a href="tel:{{ $support_number }}" style="color: {{ $theme_color }};">{{ $support_number }}</a>
                                    @endif
                                </p>
                            @endif
                            <p style="margin:0;">
                                &copy; {{ date('Y') }} {{ $app_name }}. All Rights Reserved.
                            </p>
                        </td>
                    </tr>

                </table>
            </td>
        </tr>
    </table>
</body>

</html>
