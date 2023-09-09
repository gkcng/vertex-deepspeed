0,/^#?Port 22/s//Port 2222/
s/^#?HostKey(.*)/HostKey\1/
s/^#?PubkeyAuthentication.*/PubkeyAuthentication yes/
s/^#?AuthorizedKeysFile(.*)/AuthorizedKeysFile\1/
s/^#?PasswordAuthentication.*/PasswordAuthentication no/
s/^#?UsePAM.*/UsePAM yes/
s/^#?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/
s/^#?PermitUserEnvironment.*/PermitUserEnvironment yes/
s/^#?ClientAliveInterval.*/ClientAliveInterval 60/
s/^#?ClientAliveCountMax.*/ClientAliveCountMax 3/
