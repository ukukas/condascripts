foreach ($pkg in Get-Content ".\libs.txt") {
    Write-Output $pkg
    Start-Process "python" -ArgumentList "-c `"import $pkg`"" -NoNewWindow -Wait
}