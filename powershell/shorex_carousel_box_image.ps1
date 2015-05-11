#Copyright (c) 2015 Serguei Kouzmine
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in
#all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#THE SOFTWARE.


# http://seleniumeasy.com/selenium-tutorials/set-browser-width-and-height-in-selenium-webdriver
param(
  [switch]$browser,
  [switch]$mobile,# currently unused
  [switch]$pause

)
# http://stackoverflow.com/questions/8343767/how-to-get-the-current-directory-of-the-cmdlet-being-executed
function Get-ScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  if ($Invocation.PSScriptRoot) {
    $Invocation.PSScriptRoot
  }
  elseif ($Invocation.MyCommand.Path) {
    Split-Path $Invocation.MyCommand.Path
  } else {
    $Invocation.InvocationName.Substring(0,$Invocation.InvocationName.LastIndexOf(""))
  }
}

function highlight {

  param(
    [System.Management.Automation.PSReference]$selenium_ref,
    [System.Management.Automation.PSReference]$element_ref,
    [int]$delay = 300
  )

  # https://selenium.googlecode.com/git/docs/api/java/org/openqa/selenium/JavascriptExecutor.html
  [OpenQA.Selenium.IJavaScriptExecutor]$selenium_ref.Value.ExecuteScript("arguments[0].setAttribute('style', arguments[1]);",$element_ref.Value,'color: yellow; border: 4px solid yellow;')
  Start-Sleep -Millisecond $delay
  [OpenQA.Selenium.IJavaScriptExecutor]$selenium_ref.Value.ExecuteScript("arguments[0].setAttribute('style', arguments[1]);",$element_ref.Value,'')


}


function extract_match {

  param(
    [string]$source,
    [string]$capturing_match_expression,
    [string]$label,
    [System.Management.Automation.PSReference]$result_ref = ([ref]$null)

  )

  if ($DebugPreference -eq 'Continue') {
    Write-Debug ('Extracting from {0}' -f $source)
  }

  $local:results = {}
  $local:results = $source | where { $_ -match $capturing_match_expression } |
  ForEach-Object { New-Object PSObject -prop @{ Media = $matches[$label]; } }
  $result_ref.Value = $local:results.Media
}



function set_timeouts {
  param(
    [System.Management.Automation.PSReference]$selenium_ref,
    [int]$explicit = 120,
    [int]$page_load = 600,
    [int]$script = 3000
  )

  [void]($selenium_ref.Value.Manage().Timeouts().ImplicitlyWait([System.TimeSpan]::FromSeconds($explicit)))
  [void]($selenium_ref.Value.Manage().Timeouts().SetPageLoadTimeout([System.TimeSpan]::FromSeconds($pageload)))
  [void]($selenium_ref.Value.Manage().Timeouts().SetScriptTimeout([System.TimeSpan]::FromSeconds($script)))

}


function redirect_workaround {

  param(
    [string]$web_host = '',
    [string]$app_url = '',
    [string]$app_virtual_path = ''


  )

  if ($web_host -eq $null -or $web_host -eq '') {
    throw 'Web host cannot be null'

  }

  if (($app_virtual_path -ne '') -and ($app_virtual_path -ne '')) {
    $app_url = "http://${web_host}/${app_virtual_path}"
  }


  if ($app_url -eq $null -or $app_url -eq '') {
    throw 'Url cannot be null'
  }

  # workaround for 
  # The underlying connection was closed: Could not establish
  # trust relationship for the SSL/TLS secure channel.
  # error 
  # explained in 
  # http://stackoverflow.com/questions/11696944/powershell-v3-invoke-webrequest-https-error
  Add-Type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
  [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

  $result = $null

  try {
    $result = (Invoke-WebRequest -MaximumRedirection 0 -Uri $app_url -ErrorAction 'SilentlyContinue')
    if ($result.StatusCode -eq '302' -or $result.StatusCode -eq '301') {
      $location = $result.headers.Location
      if ($location -match '^http') {
        # TODO capture the host
        $location = $location -replace 'secure.carnival.com',$web_host
      } else {
        $location = $location -replace '^/',''
        $location = ('http://{0}/{1}' -f $web_host,$location)
      }
      Write-Host ('Following {0} ' -f $location)

      $result = (Invoke-WebRequest -Uri $location -ErrorAction 'Stop')
    }
  } catch [exception]{}


  return $result.Content.length

}


function compute_media_dimensions {

  # TODO: md5 hash 
  param(
    $base_url = 'http://www.carnival.com',
    $web_host = 'www.carnival.com',
    $img_src
  )

  $img_url = ('{0}/{1}' -f $base_url,$img_src)
  $media_size = 0
  <#
    $warmup_response_time = [System.Math]::Round((Measure-Command {
          try {
            $media_size = redirect_workaround -web_host $web_host -app_url $app_url
            # (New-Object net.webclient).DownloadString($_)
          } catch [exception]{
            Write-Output ("Exception `n{0}" -f (($_.Exception.Message) -split "`n")[0])
          }
        }
      ).totalmilliseconds)
    # Write-Output ("Opening page: {0} took {1} ms" -f $app_url,$warmup_response_time)
#>
  $media_size = redirect_workaround -web_host $web_host -app_url $img_url
  return $media_size

}



function cleanup
{
  param(
    [System.Management.Automation.PSReference]$selenium_ref
  )
  try {
    $selenium_ref.Value.Quit()
  } catch [exception]{
    Write-Output (($_.Exception.Message) -split "`n")[0]

    # Ignore errors if unable to close the browser
  }
}

$shared_assemblies = @(
  'WebDriver.dll',
  'WebDriver.Support.dll',
  'nunit.framework.dll'
)

$shared_assemblies_path = 'c:\developer\sergueik\csharp\SharedAssemblies'

if (($env:SHARED_ASSEMBLIES_PATH -ne $null) -and ($env:SHARED_ASSEMBLIES_PATH -ne '')) {
  $shared_assemblies_path = $env:SHARED_ASSEMBLIES_PATH
}

pushd $shared_assemblies_path
$shared_assemblies | ForEach-Object {
  # Unblock-File -Path $_; 
  Add-Type -Path $_
}
popd
[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
$verificationErrors = New-Object System.Text.StringBuilder
$phantomjs_executable_folder = 'C:\tools\phantomjs'
if ($PSBoundParameters["browser"]) {
  try {
    $connection = (New-Object Net.Sockets.TcpClient)
    $connection.Connect("127.0.0.1",4444)
    $connection.Close()
  } catch [exception]{
    Write-Output ('Exception: {0}' -f (($_.Exception.Message) -split "`n")[0])
    Start-Process -FilePath "C:\Windows\System32\cmd.exe" -ArgumentList "start cmd.exe /c c:\java\selenium\hub.cmd"
    Start-Process -FilePath "C:\Windows\System32\cmd.exe" -ArgumentList "start cmd.exe /c c:\java\selenium\node.cmd"
    Start-Sleep -Seconds 10
  }


  if ($PSBoundParameters["mobile"].IsPresent) {
    # note $profile is not set
    [OpenQA.Selenium.Firefox.FirefoxProfile]$selected_profile_object = $profile_manager.GetProfile($profile)
    [OpenQA.Selenium.Firefox.FirefoxProfile]$selected_profile_object = New-Object OpenQA.Selenium.Firefox.FirefoxProfile ($profile)
    $selected_profile_object.setPreference('general.useragent.override','Mozilla/5.0 (iPhone; U; CPU iPhone OS 3_0 like Mac OS X; en-us) AppleWebKit/528.18 (KHTML, like Gecko) Version/4.0 Mobile/7A341 Safari/528.16')

    [OpenQA.Selenium.Firefox.FirefoxProfile[]]$profiles = $profile_manager.ExistingProfiles

    # [NUnit.Framework.Assert]::IsInstanceOfType($profiles , new-object System.Type( FirefoxProfile[]))
    [NUnit.Framework.StringAssert]::AreEqualIgnoringCase($profiles.GetType().ToString(),'OpenQA.Selenium.Firefox.FirefoxProfile[]')


    $selenium = New-Object OpenQA.Selenium.Firefox.FirefoxDriver ($selected_profile_object)
  } else {
    $uri = [System.Uri]("http://127.0.0.1:4444/wd/hub")
    $capability = [OpenQA.Selenium.Remote.DesiredCapabilities]::Firefox()
    $selenium = New-Object OpenQA.Selenium.Remote.RemoteWebDriver ($uri,$capability)
  }
  $DebugPreference = 'Continue'

} else {
  $selenium = New-Object OpenQA.Selenium.PhantomJS.PhantomJSDriver ($phantomjs_executable_folder)
  $selenium.Capabilities.SetCapability("ssl-protocol","any")
  $selenium.Capabilities.SetCapability("ignore-ssl-errors",$true)
  $selenium.Capabilities.SetCapability("takesScreenshot",$true)
  if ($PSBoundParameters["mobile"].IsPresent) {
    $selenium.Capabilities.SetCapability("userAgent","Mozilla/5.0 (Windows NT 6.1) AppleWebKit/534.34 (KHTML, like Gecko) PhantomJS/1.9.7 Safari/534.34")
  }
  $options = New-Object OpenQA.Selenium.PhantomJS.PhantomJSOptions
  $options.AddAdditionalCapability("phantomjs.executable.path",$phantomjs_executable_folder)
}
[void]$selenium.Manage().Timeouts().SetScriptTimeout([System.TimeSpan]::FromSeconds(3000))

if ($PSBoundParameters["mobile"].IsPresent) {
  if ($host.Version.Major -le 2) {
    [void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
    $selenium.Manage().Window.Size = New-Object System.Drawing.Size (480,600)
    $selenium.Manage().Window.Position = New-Object System.Drawing.Point (0,0)
  } else {
    $selenium.Manage().Window.Size = @{ 'Height' = 600; 'Width' = 480; }
    $selenium.Manage().Window.Position = @{ 'X' = 0; 'Y' = 0 }
  }
}
$window_position = $selenium.Manage().Window.Position
$window_size = $selenium.Manage().Window.Size





$base_url = 'http://www.carnival.com/shore-excursions/party/my-jamaican-home-for-the-day-425123'
$selenium.Navigate().GoToUrl($base_url)
# set_timeouts ([ref]$selenium)
# $selenium.Navigate().Refresh()


$css_selector = 'div.carousel-wrapper div.owl-item div.item'
Write-Output ('Locating via CSS SELECTOR: "{0}"' -f $css_selector)

[OpenQA.Selenium.Support.UI.WebDriverWait]$wait = New-Object OpenQA.Selenium.Support.UI.WebDriverWait ($selenium,[System.TimeSpan]::FromSeconds(1))
$wait.PollingInterval = 100
try {
  [void]$wait.Until([OpenQA.Selenium.Support.UI.ExpectedConditions]::ElementExists([OpenQA.Selenium.By]::CssSelector($css_selector)))
} catch [exception]{
}

[OpenQA.Selenium.IWebElement[]]$carousel_items = $selenium.FindElements([OpenQA.Selenium.By]::CssSelector($css_selector))
Write-Output ('Iterating over {0} items' -f $carousel_items.Count)

$index = 0
$max_count = 100
$sample_cnt = 99
[bool]$found = $false
foreach ($item in $carousel_items)
{
  if ($index -gt $max_count) {
    continue
  }
  Write-Output 'Getting the media URL'
  $css_img_selector = 'img'

  $item_img = $item.FindElement([OpenQA.Selenium.By]::CssSelector($css_img_selector))

  if (-not $item_img.Displayed) {

    $arrow_next_selector = 'div[class*=nav-right][class*=carousel-nav] div[class*=arrow-next]'
    $arrow_next_element = $selenium.FindElement([OpenQA.Selenium.By]::CssSelector($arrow_next_selector))
    [OpenQA.Selenium.Interactions.Actions]$actions2 = New-Object OpenQA.Selenium.Interactions.Actions ($selenium)
    [void]$actions2.MoveToElement([OpenQA.Selenium.IWebElement]$arrow_next_element).Build().Perform()
    Start-Sleep -Milliseconds 100
    [void]$actions2.MoveToElement([OpenQA.Selenium.IWebElement]$arrow_next_element).click().Build().Perform()
    <#
      $actions2.clickAndHold($arrow_next_element)
      $actions2.release()
    #>
    $item_img = $item.FindElement([OpenQA.Selenium.By]::CssSelector($css_img_selector))
    Start-Sleep -Milliseconds 200
    # Assert $item_img.Displayed

  }
  highlight ([ref]$selenium) ([ref]$item_img)
  $item_img.click()
  Start-Sleep -Milliseconds 100
  $image_preview_selector = 'div[class *=modal] div[style^=background-image]'
  $image_preview_element = $selenium.FindElement([OpenQA.Selenium.By]::CssSelector($image_preview_selector))
  $image_preview_src = $null
  # write-output $image_preview_element.GetAttribute('style')
  extract_match -Source $image_preview_element.GetAttribute('style') -capturing_match_expression 'url\(\"(?<media>.+)\"\)' -label 'media' -result_ref ([ref]$image_preview_src)
  Write-Output ('Preview Image: {0}' -f $image_preview_src)
  $media_size = compute_media_dimensions -img_src $image_preview_src
  Write-Host ('Media size : {0}' -f $media_size)

  $close_selector = 'div[class *=modal] a[class*=close]'
  $close_element = $selenium.FindElement([OpenQA.Selenium.By]::CssSelector($close_selector))
  $close_element.click()
  Start-Sleep -Milliseconds 100


  $carousel_img_src = $item_img.GetAttribute("data-main-img-src")
  $photopreview_cnt = $item_img.GetAttribute("photopreview")
  Write-Output ('Screen Location: {0}' -f $item.LocationOnScreenOnceScrolledIntoView.X)
  Write-Output ('Count = {0}' -f $photopreview_cnt)
  Write-Output ('Carousel Image: {0}' -f $carousel_img_src)
  $media_size = compute_media_dimensions -img_src $carousel_img_src
  Write-Host ('Media size : {0}' -f $media_size)
  $index++
}

Start-Sleep -Milliseconds 1000
# Cleanup
cleanup ([ref]$selenium)


