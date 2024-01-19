# Measure-SFDatacenterResponseTime PowerShell Function

## Overview

The `Measure-SFDatacenterResponseTime` function is a PowerShell script that helps you to measure the response times for different SuccessFactors (SF) data centers. This function is handy for evaluating the performance of SF instances across different geographical locations.

## Features

- Measure response times from your system to different SF data centers.
- Option to ignore SSL certificate validation.
- Option to use a web proxy.
- Data centers with faster response times are listed first.

## Usage

Here is an example of how to call the function:

```powershell
Measure-SFDatacenterResponseTime
```

### Parameters

- `-Proxy` - Accepts a [System.Net.WebProxy](https://docs.microsoft.com/en-us/dotnet/api/system.net.webproxy?view=netframework-4.8) object. The script will use this proxy when making web requests. This is optional and not required if you're not using a proxy server.

- `-IgnoreSSL` - Ignore SSL certificate validation. This can be useful in environments with self-signed certificates or for testing purposes. Note that you should not use this option in a production environment as it bypasses important security checks.

### Output

The function outputs a table in the console with the following columns:

- `datacenter`: SF Data center code
- `region`: Geographical region of the data center
- `address`: Physical address of the data center
- `URL`: URL for the SF instance at the data center
- `respTime(ms)`: Response time in milliseconds from your system to the SF instance at the data center

### Example Output

```
datacenter region address                   URL                                      respTime(ms)
---------- ------ -------                   ---                                      ------------
DC70       AMER   Virginia MS Azure             https://performancemanager8.successfactors.com        301.73
DC66       APAC   Sydney MS Azure               https://performancemanager10.successfactors.com       315.95
...
```

## License

Copyright (c) Microsoft Corporation.
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.