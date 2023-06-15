Function Measure-SFDatacenterResponseTime {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false)]
    [System.Net.WebProxy]$Proxy,

    [Parameter(Mandatory = $false)]
    [switch]$IgnoreSSL
  )

  Begin {
    if ($IgnoreSSL) {
      [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    }
    # build a hash table of successfactor datacenter, address and production URL
    # region is purely a label for the datacenter region and can be changed
    $succfac = @(
      @{datacenter = "DC57"; address = "Google GCP Eemshaven"; region = "EMEA"; URL = "https://performancemanager.successfactors.eu" }
      @{datacenter = "DC68"; address = "Virginia MS Azure"; region = "AMER"; URL = "https://performancemanager4.successfactors.com" }
      @{datacenter = "DC70"; address = "Virginia MS Azure"; region = "AMER"; URL = "https://performancemanager8.successfactors.com" }
      @{datacenter = "DC66"; address = "Sydney MS Azure"; region = "APAC"; URL = "https://performancemanager10.successfactors.com" }
      @{datacenter = "DC33"; address = "SAP Converged Cloud Frankfurt"; region = "EMEA"; URL = "https://performancemanager5.successfactors.eu" }
      @{datacenter = "DC30"; address = "SAP Converged Cloud Shanghai"; region = "APAC"; URL = "https://performancemanager15.sapsf.cn" }
      @{datacenter = "DC16"; address = "Magdeburg, Germany"; region = "EMEA"; URL = "https://hcm16.sapsf.eu" }
      @{datacenter = "DC22"; address = "Dubai"; region = "EMEA"; URL = "https://hcm22.sapsf.com" }
      @{datacenter = "DC23"; address = "Riyadh"; region = "EMEA"; URL = "https://hcm23.sapsf.com" }
      @{datacenter = "DC41"; address = "East US"; region = "AMER"; URL = "https://hcm41.sapsf.com" }
      @{datacenter = "DC42"; address = "East US"; region = "AMER"; URL = "https://hcm42.sapsf.com" }
      @{datacenter = "DC47"; address = "Azure/Canada"; region = "AMER"; URL = "https://hcm47.sapsf.com" }
      @{datacenter = "DC50"; address = "GCP Tokyo"; region = "APAC"; URL = "https://hcm50.sapsf.com" }
      @{datacenter = "DC52"; address = "GCP - Singapore"; region = "SEA"; URL = "https://hcm44.sapsf.com" }
      @{datacenter = "DC55"; address = "Frankfurt"; region = "EMEA"; URL = "https://hcm55.sapsf.eu" }
      @{datacenter = "DC60"; address = "Canada Central"; region = "AMER"; URL = "https://hcm17.sapsf.com" }
      @{datacenter = "DC62"; address = "São Paulo"; region = "LATAM"; URL = "https://hcm19.sapsf.com" }
    )
  }

  Process {
    # loop through each datacenter in the hash table
    # calculate response times
    $SuccFac | ForEach-Object {
      try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $request = [System.Net.HttpWebRequest]::Create($_.URL)
        $request.Proxy = $Proxy
        $request.Method = "GET"
        $response = $request.GetResponse()
        $stopwatch.Stop()
        $_.Add("respTime(ms)", $stopwatch.Elapsed.TotalMilliseconds)
      }
      catch [System.Exception] {
        Write-Error -Message "$($_.Exception.Message)"
      }
    }
    # output the datacenter, address and response time to the console
    # for the datacenter with the fastest response time in the first row
    # exclude rows that do not have a value for response time
    $SuccFac | Where-Object { $_.'respTime(ms)' } | `
      Select-Object datacenter, region, address, URL, 'respTime(ms)' | `
      Sort-Object -Property 'respTime(ms)'

  }

  End {
    if ($IgnoreSSL) {
      [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $null }
    }
  }
}

Measure-SFDatacenterResponseTime