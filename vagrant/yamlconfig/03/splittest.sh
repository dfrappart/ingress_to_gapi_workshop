while true; do curl -s -k "http://k8scalico1:31481" >> curlresponses.txt ;done

cat curlresponses.txt | grep -i exia | wc -l


cat curlresponses.txt | grep -i eva02 | wc -l
