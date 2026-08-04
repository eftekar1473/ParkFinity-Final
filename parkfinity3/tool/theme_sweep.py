import io, re, sys

FILES = [
 'lib/features/rider/presentation/screens/my_vehicles_screen.dart',
 'lib/features/rider/presentation/screens/smart_recommendations_screen.dart',
 'lib/features/owner/presentation/screens/add_listing_screen.dart',
 'lib/features/auth/presentation/screens/login_screen.dart',
 'lib/features/rider/presentation/widgets/filter_sheet.dart',
 'lib/features/owner/presentation/screens/owner_dashboard_screen.dart',
 'lib/features/shared/presentation/screens/notifications_screen.dart',
 'lib/features/owner/presentation/screens/edit_listing_screen.dart',
 'lib/features/shared/presentation/widgets/review_sheet.dart',
 'lib/features/auth/presentation/screens/kyc_upload_screen.dart',
 'lib/features/owner/presentation/widgets/listing_form_fields.dart',
 'lib/features/auth/presentation/screens/role_selection_screen.dart',
 'lib/features/auth/presentation/screens/register_screen.dart',
 'lib/features/parking/presentation/screens/qr_scan_screen.dart',
]

T = 'Theme.of(context)'
CS = T + '.colorScheme'

# Order matters: most specific first.
RULES = [
    (r'Colors\.deepPurple\.shade900',            CS + '.onPrimaryContainer'),
    (r'Colors\.deepPurple\.shade(50|100)\b',     CS + '.primaryContainer'),
    (r'Colors\.deepPurple\.shade\d+',            CS + '.primary'),
    (r'Colors\.deepPurple\.withValues\(alpha: ([0-9.]+)\)',
                                                 CS + r'.primary.withValues(alpha: \1)'),
    (r'Colors\.deepPurple\b',                    CS + '.primary'),

    (r'Colors\.red\.shade\d+',                   CS + '.error'),
    (r'Colors\.red\b',                           CS + '.error'),

    (r'Border\.all\(color: Colors\.grey(?:\[\d+\]|\.shade\d+)?',
                                                 'Border.all(color: ' + T + '.dividerColor'),
    (r'BorderSide\(color: Colors\.grey(?:\[\d+\]|\.shade\d+)?',
                                                 'BorderSide(color: ' + T + '.dividerColor'),
    (r'backgroundColor: Colors\.grey(?:\[\d+\]|\.shade\d+)?',
                                                 'backgroundColor: ' + CS + '.surface'),
    (r'color: Colors\.grey(?:\[\d+\]|\.shade\d+)?',
                                                 'color: ' + T + '.hintColor'),
    (r'Colors\.grey(?:\[\d+\]|\.shade\d+)?',     T + '.hintColor'),

    (r'backgroundColor: Colors\.white',          'backgroundColor: ' + CS + '.surfaceContainerLow'),
    (r'foregroundColor: Colors\.white',          'foregroundColor: ' + CS + '.onPrimary'),
    (r'color: Colors\.white70',                  CS + '.onPrimary.withValues(alpha: 0.7)'),
    (r'color: Colors\.white',                    'color: ' + CS + '.surfaceContainerLow'),
    (r'Colors\.white\b',                         CS + '.surfaceContainerLow'),

    (r'color: Colors\.black87',                  'color: ' + CS + '.onSurface'),
    (r'color: Colors\.black\b(?!\.)',            'color: ' + CS + '.onSurface'),
]

# Lines that gain Theme.of(context) can no longer sit in a const expression.
CONST_PAT = re.compile(r'\bconst\b\s+')

for path in FILES:
    src = io.open(path, encoding='utf-8').read()
    out_lines = []
    for line in src.split('\n'):
        orig = line
        for pat, rep in RULES:
            line = re.sub(pat, rep, line)
        if line != orig and 'Theme.of(context)' in line:
            line = CONST_PAT.sub('', line)
        out_lines.append(line)
    new = '\n'.join(out_lines)
    if new != src:
        io.open(path, 'w', encoding='utf-8', newline='\n').write(new)
        print('rewrote', path)
