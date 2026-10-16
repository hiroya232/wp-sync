<?php
// Usage: php -- <constants_csv> <tmp_file> <wp_config_path> (スクリプトは標準入力で渡す)
$constants = explode(',', $argv[1]);
$tmp_file = $argv[2];
$wp_config_path = $argv[3];

$tmp_content = file_get_contents($tmp_file);
$wp_content = file_get_contents($wp_config_path);

if ($tmp_content === false || $wp_content === false) {
    file_put_contents('php://stderr', "ERROR: Cannot read input files\n");
    exit(1);
}

$replaced = 0;
foreach ($constants as $constant) {
    $constant = trim($constant);
    if (empty($constant)) continue;

    $pattern = '/^[ \t]*define\s*\(\s*\'' . preg_quote($constant, '/') . '\'.*/m';

    if (preg_match($pattern, $tmp_content, $match)) {
        if (preg_match($pattern, $wp_content)) {
            $replacement = $match[0];
            $wp_content = preg_replace_callback($pattern, function() use ($replacement) {
                return $replacement;
            }, $wp_content, 1);
        } else {
            $replacement = $match[0];
            $wp_content = preg_replace_callback(
                '/^(if\s*\(\s*!\s*defined)/m', function($m) use ($replacement) {
                    return $replacement . "\n" . $m[0];
                },
                $wp_content,
                1
            );
        }
        $replaced++;
    }
}

if ($replaced === 0) {
    file_put_contents('php://stderr', "ERROR: No constants were replaced in wp-config.php\n");
    exit(1);
}

if (empty(trim($wp_content))) {
    file_put_contents('php://stderr', "ERROR: wp-config.php is empty after constant restore\n");
    exit(1);
}

if (file_put_contents($wp_config_path, $wp_content) === false) {
    file_put_contents('php://stderr', "ERROR: Failed to write wp-config.php\n");
    exit(1);
}

unlink($tmp_file);
