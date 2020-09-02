---
title: "PHP 生成 Excel"
date: 2014-12-12T20:10:14+08:00
draft: false
categories: ["PHP"]
tags: ["PHP"]
---

在 `php` 中，比如要下载一个表单，不一定必须要用诸如 `PHPExcel`，或在服务器上生成 `txt`、`csv`等文件。

我们可以利用 `html` 的 `table`，指定对应的 `Content-type`（告诉浏览器），`MS Excel` 一样可以解析。

源码如下：

```php
$req = $_POST + $_GET;
$filename = htmlspecialchars(trim($req['filename']));
$html = trim($req['html']); // 通常是一个 table 的 html

if (!$filename) {
	$filename = "export_" . date('YmdHis');
}

$text = "
<html>
<head>
</head>
<body>
$html
</body>
</html>
";

// 发送 header
header("Content-type:application/vnd.ms-excel");
header("Content-Disposition:filename=$filename.xls");
echo $text;
exit;
```

## excel 单元格格式调整

通过上述方法生成的 `Excel`，`MS Excel` 在解析的时候，会遇到将长数字转换成科学计数法的问题，且溢出后尾数为 0 等。

这里，我们只需要简单的在 `td` 标签增加一些 `style` 即可。如

```html
<td style="vnd.ms-excel.numberformat:@">20180917144623254615</td>
```

常见的 `MS Excel` 的 `style` 如下：

```
1） 文本：vnd.ms-excel.numberformat:@ 
2） 日期：vnd.ms-excel.numberformat:yyyy/mm/dd 
3） 数字：vnd.ms-excel.numberformat:#,##0.00 
4） 货币：vnd.ms-excel.numberformat:￥#,##0.00 
5） 百分比：vnd.ms-excel.numberformat: #0.00% 
```
