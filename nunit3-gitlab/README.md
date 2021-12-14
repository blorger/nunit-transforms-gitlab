### nunit3-junit-gitlab -- Blaž Lorger

Converts NUnit3 results to JUnit-style results. It deliberately drops some information and rearranges it in somewhat unusual way. The intention is to produce a results file suitable for publishing to GitLab via the JUnit report publisher.

#### GitLab JUnit dialect
This is description of [GitLab 14.5.2 JUnit test report parser](https://gitlab.com/gitlab-org/gitlab/-/blob/v14.5.2-ee/lib/gitlab/ci/parsers/test/junit.rb).

Parser converts XML to hash. There is basically no distinction between element text and attribute values.

All test cases regardless of test status extract data from following elements or attributes:
* `suite_name` - test suite name
* `classname` - test class name
* `name` - test case name
* `time` - test runtime
* `file` - reference to file in Git repository
    <br/>Reference should be file path relative to repository root.
    It can also contain line number anchor (i.e. `one/two/file.js#L55`).

Test status is determined based on element containing test result description.
Attribute `status` is completely ignored.
Supported test status elements are:
* `failure`, `error`
    * Element text is presented as test details.
    * `ATTACHMENT` tag in `system_out` element text is added as test report attachment.
    <br/>Only first attachment tag is used. Subsequent tags are ignored.
    <br/>Provided attachment reference should be relative file location in GitLab job artifacts.
* `skipped`
    * Element text is presented as test details.
* Other elements are ignored. No test details are added to the report. Test status will be recorded as successful.

#### GitLab CI/CD

Here is an example how to include transformation in GitLab CI/CD pipeline for shell (PowerShell) runner
and mark job as acceptably failed when just unit-tests fail.

```yml
variables:
  NUNIT_REPORT_DIRECTORY: ".\\nunit3-gitlab\\NUnit"
  TEST_REPORT_DIRECTORY: "$CI_PROJECT_DIR\\out"
  NUNIT_XSLT: "$CI_PROJECT_DIR\\nunit3-gitlab\\nunit3-junit-gitlab.xslt"
  ATTACHMENTS_ROOT: "$ENV:CI_PROJECT_DIR\\"
stages:
  - build

build_job:
  stage: build
  tags:
    - Windows
  allow_failure:
    exit_codes: 33554432
  script:
    - |
        $ErrorActionPreference = "Stop";
        
        # Actually build code and execute unit tests. Don't fail if only some unit test fail.
        
        $reports = Get-ChildItem -Path $ENV:NUNIT_REPORT_DIRECTORY -Filter "*.xml";
        $foundFailedTests = $false;
        if ($reports) {
            New-Item -Type Directory -Path $ENV:TEST_REPORT_DIRECTORY -Force | Out-Null;
            $xslt = New-Object System.Xml.Xsl.XslCompiledTransform;
            $xslt.Load($ENV:NUNIT_XSLT) | Out-Null;
            $arg = New-Object System.Xml.Xsl.XsltArgumentList;
            $arg.AddParam("WorkingCopy", "", $ENV:ATTACHMENTS_ROOT);
            $reports | ForEach-Object {
                $output = Join-Path $ENV:TEST_REPORT_DIRECTORY $_.Name;
                $writer =[System.Xml.XmlWriter]::Create($output, $xslt.OutputSettings);
                $xslt.Transform($_.FullName, $arg, $writer);
                $writer.Close();
                if (-not $foundFailedTests) {
                    $report = New-Object System.Xml.XmlDocument;
                    $report.Load($_.FullName);
                    $testResult = $report.SelectSingleNode("/test-run/@result").Value;
                    $foundFailedTests =  $testResult -ne "Passed" -and $testResult -ne "Skipped";
                }
            }
        }
        if ($foundFailedTests) {
          $host.SetShouldExit(33554432); # workaround for https://gitlab.com/gitlab-org/gitlab-runner/-/issues/28244
          exit 33554432;
        }

  artifacts:
    expire_in: 2 day
    reports:
      junit:
        - 'out/*.xml'
```