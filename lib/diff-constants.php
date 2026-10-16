<?php
// Usage: php -- <src_wp_config> <dst_wp_config> (スクリプトは標準入力で渡す)
// 両ファイルに存在し値が異なる定数名をCSVで標準出力する
$src_path = $argv[1];
$dst_path = $argv[2];

$src_content = file_get_contents($src_path);
$dst_content = file_get_contents($dst_path);

if ($src_content === false || $dst_content === false) {
    file_put_contents('php://stderr', "ERROR: Cannot read input files\n");
    exit(1);
}

function extract_constants($content) {
    $constants = [];
    $pattern = '/^[ \t]*define\s*\(\s*[\'"]([^\'"]+)[\'"]\s*,\s*(.+?)\s*\)\s*;/m';
    if (preg_match_all($pattern, $content, $matches, PREG_SET_ORDER)) {
        foreach ($matches as $match) {
            $constants[$match[1]] = $match[2];
        }
    }
    return $constants;
}

$src_constants = extract_constants($src_content);
$dst_constants = extract_constants($dst_content);

$diff = [];
foreach ($src_constants as $name => $src_value) {
    if (isset($dst_constants[$name]) && $dst_constants[$name] !== $src_value) {
        $diff[] = $name;
    }
}

echo implode(',', $diff);
