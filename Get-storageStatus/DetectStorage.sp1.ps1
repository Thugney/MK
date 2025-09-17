$storageThreshold = 15

$utilization = (Get-PSDrive | Where {$_.name -eq "C"}).free

if(($storageThreshold *1GB) -lt $utilization){exit 0}
else{exit 1}