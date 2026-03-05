#!/usr/bin/env raku
# Generate HTML documentation from POD6 files

use Pod::To::HTML;
use JSON::Fast;

my @modules;

# Find all .rakumod files
for dir('lib', :recursive) -> $file {
    next unless $file.ends-with('.rakumod');
    
    my $module-name = $file.Str.subst('lib/', '').subst('/', '::', :g).subst('.rakumod', '');
    my $html-file = $file.Str.subst('lib/', '').subst('/', '_', :g).subst('.rakumod', '.html');
    
    say "Processing $file -> $html-file";
    
    # Extract POD and convert to HTML
    my $html = qq:to/HTML/;
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>$module-name - Nats.raku</title>
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; max-width: 900px; margin: 2em auto; padding: 0 1em; line-height: 1.6; color: #333; }}
            h1 {{ color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 0.3em; }}
            h2 {{ color: #34495e; margin-top: 1.5em; }}
            h3 {{ color: #555; }}
            code {{ background: #f4f4f4; padding: 2px 6px; border-radius: 3px; font-family: Consolas, monospace; font-size: 0.9em; }}
            pre {{ background: #f4f4f4; padding: 1em; border-radius: 5px; overflow-x: auto; }}
            pre code {{ background: none; padding: 0; }}
            a {{ color: #3498db; text-decoration: none; }}
            a:hover {{ text-decoration: underline; }}
            .header {{ background: #2c3e50; color: white; padding: 1em; margin: -2em -1em 2em -1em; }}
            .header h1 {{ border: none; color: white; margin: 0; }}
            .header a {{ color: #3498db; }}
            .nav {{ margin-top: 2em; padding-top: 1em; border-top: 1px solid #ddd; }}
            .method {{ margin: 1em 0; padding: 1em; background: #f9f9f9; border-left: 4px solid #3498db; }}
            .method-name {{ font-weight: bold; color: #2c3e50; }}
        </style>
    </head>
    <body>
        <div class="header">
            <h1>$module-name</h1>
            <p><a href="/">← Back to Nats.raku</a> | <a href="/api/">API Index</a></p>
        </div>
        <div class="content">
    HTML
    
    # Try to extract POD and convert
    try {
        my $pod = Pod::Load.load($file.Str);
        $html ~= Pod::To::HTML.render($pod);
    }
    catch {
        $html ~= "<p><em>Documentation for $module-name</em></p>";
        $html ~= "<p>POD extraction failed: $_</p>";
    }
    
    $html ~= q:to/FOOTER/;
        </div>
        <div class="nav">
            <p><a href="/">← Back to main documentation</a></p>
        </div>
    </body>
    </html>
    FOOTER
    
    # Write HTML file
    "_site/api/$html-file".IO.spurt($html);
    
    @modules.push: {
        name => $module-name,
        file => $html-file,
        path => $file.Str
    };
}

# Generate API index
my $index = q:to/INDEX/;
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Nats.raku API Documentation</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; max-width: 900px; margin: 2em auto; padding: 0 1em; line-height: 1.6; color: #333; }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 0.3em; }
        h2 { color: #34495e; margin-top: 1.5em; }
        ul { list-style: none; padding: 0; }
        li { margin: 0.8em 0; padding: 0.8em; background: #f8f9fa; border-radius: 4px; border-left: 4px solid #3498db; }
        li:hover { background: #e9ecef; }
        a { color: #3498db; text-decoration: none; font-weight: 500; font-size: 1.1em; }
        a:hover { text-decoration: underline; }
        .module-path { color: #666; font-size: 0.85em; font-family: monospace; }
        .header { background: #2c3e50; color: white; padding: 1em; margin: -2em -1em 2em -1em; }
        .header h1 { border: none; color: white; margin: 0; }
        .header a { color: #3498db; }
        .nav { margin-top: 2em; padding-top: 1em; border-top: 1px solid #ddd; }
    </style>
</head>
<body>
    <div class="header">
        <h1>📚 Nats.raku API Documentation</h1>
        <p><a href="/">← Back to main</a></p>
    </div>
    
    <p>Complete API documentation for all modules. Click on a module name to view its documentation.</p>
    
    <h2>📦 Modules</h2>
    <ul>
INDEX

for @modules.sort(*<name>) -> $mod {
    $index ~= "        <li>\n";
    $index ~= "            <a href=\"{$mod<file>}\">{$mod<name>}</a><br>\n";
    $index ~= "            <span class=\"module-path\">{$mod<path>}</span>\n";
    $index ~= "        </li>\n";
}

$index ~= q:to/END/;
    </ul>
    
    <div class="nav">
        <p><a href="/">← Back to main documentation</a></p>
    </div>
</body>
</html>
END

"_site/api/index.html".IO.spurt($index);

say "Generated {@modules.elems} module documentation files";

# Generate main index from README
my $readme = "README.md".IO.slurp;

# Simple Markdown to HTML conversion
my $main-index = q:to/MAIN/;
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Nats.raku - Raku client for NATS.io</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; max-width: 900px; margin: 2em auto; padding: 0 1em; line-height: 1.6; color: #333; }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 0.3em; }
        h2 { color: #34495e; margin-top: 1.5em; border-bottom: 1px solid #eee; padding-bottom: 0.2em; }
        h3 { color: #555; }
        code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; font-family: Consolas, monospace; font-size: 0.9em; }
        pre { background: #f4f4f4; padding: 1em; border-radius: 5px; overflow-x: auto; }
        pre code { background: none; padding: 0; }
        a { color: #3498db; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .header { background: #2c3e50; color: white; padding: 1em; margin: -2em -1em 2em -1em; }
        .header h1 { border: none; color: white; margin: 0; }
        .header a { color: #3498db; }
        .button { display: inline-block; padding: 0.8em 1.5em; background: #3498db; color: white; border-radius: 4px; margin: 0.5em 0; }
        .button:hover { background: #2980b9; text-decoration: none; }
        .nav { margin-top: 2em; padding-top: 1em; border-top: 1px solid #ddd; }
        .api-button { background: #27ae60; }
        .api-button:hover { background: #219a52; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Nats.raku</h1>
        <p>Raku client for NATS.io messaging system</p>
        <p><a href="https://github.com/FCO-openclaw/nats.raku">GitHub Repository</a></p>
    </div>
    
    <p>
        <a href="/api/" class="button api-button">📚 API Documentation</a>
        <a href="https://github.com/FCO-openclaw/nats.raku" class="button">GitHub</a>
    </p>
    
    <hr>
MAIN

# Simple markdown conversion
my $content = $readme;
$content .= subst(/^ '#'/, '', :g);  # Remove # from headers
$content .= subst(/^ '## ' /, '<h2>', :g);
$content .= subst(/^ '### ' /, '<h3>', :g);
$content .= subst(/ ' \n' /, "</h2>\n", :g);
$content .= subst(/ ' \n' /, "</h3>\n", :g);
$content .= subst(/ '```' .*? '```' /, { '<pre><code>' ~ $/.subst('```', '', :g) ~ '</code></pre>' }, :g);
$content .= subst(/ '`' (.*?) '`' /, { '<code>' ~ $0 ~ '</code>' }, :g);

$main-index ~= "<div class=\"content\">\n";
$main-index ~= $content;
$main-index ~= "</div>\n";

$main-index ~= q:to/FOOTER/;
    <div class="nav">
        <p><a href="/api/" class="button api-button">📚 Browse API Documentation →</a></p>
    </div>
</body>
</html>
FOOTER

"_site/index.html".IO.spurt($main-index);

say "Main index generated";
