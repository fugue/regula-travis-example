# regula-travis-example

[Regula](https://github.com/fugue/regula) is a tool that evaluates CloudFormation and Terraform infrastructure-as-code for potential AWS, Azure, and Google Cloud security misconfigurations and compliance violations prior to deployment.

This repo contains an example of integrating Regula with [Travis CI](https://travis-ci.com/) for automated testing of Azure resources declared in Terraform. In this walkthrough, we’ll show how Regula catches a security vulnerability and fails the CI build, and we’ll show how to remediate the violation so the build passes.

When we’re done, the CI/CD pipeline will work like so:

1. You commit IaC to a branch.
2. You push the commits and create a PR, triggering a Travis CI build.
3. Travis CI runs Regula against your repository.
4. If the IaC in your repo passes all of Regula’s checks, the Travis build passes. Otherwise, it fails.

## Getting started

There are a couple prerequisites for this walkthrough:

- Create a new [GitHub repo](https://docs.github.com/en/github/getting-started-with-github/quickstart/create-a-repo)
- Sign up for a (free) [Travis CI](https://travis-ci.com/) account

### Set up GitHub repo

In your terminal, [git clone](https://git-scm.com/docs/git-clone) your new repo.

Next, create a new branch:

```
git checkout -b regula-example
```

Simply download the ZIP of **this repo** and unzip the files into your own repo’s directory. You should see these files:

- [`dev_network/main.tf`](https://github.com/fugue/regula-travis-example/blob/main/dev_network/main.tf) – a Terraform file with an intentional vulnerability
- [`.travis.yml`](https://github.com/fugue/regula-travis-example/blob/main/.travis.yml) – a Travis CI build configuration file

We’ll explain what each one does shortly.

### Set up Travis CI

Now we’ll set up Travis CI to run builds for your new repository. Access your Travis Dashboard, click on your profile picture in the top right, and select **Settings**.

In the **Settings** menu, click the **Activate** button under **GitHub Apps Integration** and then select the repository you created.

Once we add a build configuration file (which we’ll do momentarily!), Travis will be able to run builds for your repository.

## The files

Let’s examine the files you added to your repository, starting with [`dev_network/main.tf`](https://github.com/fugue/regula-travis-example/blob/main/dev_network/main.tf).

### The vulnerable Terraform

The [`dev_network/main.tf`](https://github.com/fugue/regula-travis-example/blob/main/dev_network/main.tf) Terraform HCL file declares the following Microsoft Azure resources:

- Resource group
- Network security group (NSG) with one security rule
- Virtual network
- Network Watcher
- Log Analytics workspace
- Network Watcher flow log
- Storage account
- Random string, to generate a unique storage account/resource group name

For learning purposes, we’ve **intentionally created a security vulnerability** in the NSG with the single security rule (so don’t provision this Terraform in the real world!). If you take a close look at [**lines 31-41**](https://github.com/fugue/regula-travis-example/blob/main/dev_network/main.tf#L31-L41), you’ll see that port 22 is open to the world, `["0.0.0.0/0"]`:

```
  security_rule {
    name                        = "dev-nsg-rule"
    priority                    = 100
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_ranges     = ["22"]
    source_address_prefixes     = ["0.0.0.0/0"]
    destination_address_prefix  = "*"
  }
```

We certainly wouldn’t want this to make it to production! Fortunately, this is exactly the sort of issue that Regula can catch during testing. Regula has hundreds of rules that check for security vulnerabilities and compliance violations, including wide-open ports like this one.

We’re going to walk through the process of committing this code to a GitHub repo so we can see Regula in action. But first, let’s examine the Travis build configuration file so we can see exactly what will happen.

### Travis configuration

[`.travis.yml`](https://github.com/fugue/regula-travis-example/blob/main/.travis.yml) tells Travis to do the following when a build is triggered:

- Download, unzip, and install Regula in `"$HOME/.local/bin"`
- Create a temporary file for Regula output
- Run Regula to check all IaC in the repo for security and compliance, writing output to stdout and the temp file
- Show the number of passed and failed rules
- If any rules failed, the build fails; otherwise the build passes

## Kick off a build

Time to put Regula to work!

You should be on the `regula-example` branch you checked out at the beginning of this tutorial. Go ahead and add the two files to your branch:

```
git add .travis.yml dev_network
```

Commit the files:

```
git commit -m "Add Travis and Terraform IaC"
```

Now push the changes:

```
git push --set-upstream origin regula-example
```

Open up [github.com](https://www.github.com) and navigate to your repo, then access the **Pull requests** tab and select **New pull request**.

Create the PR, and you’ll see that Travis has automatically kicked off two builds: one for the branch, and one for the PR. (In this example, Travis uses the same configuration for both, so the results will be identical.)

Access the Checks tab of your PR to see the failed builds. The branch test and the PR test are listed on the left. Select either one and click the link in "The build failed."

You’ll be taken to Travis’s job log, where you can see details about the run.

Scroll down and you’ll see the output from Regula’s tests. At the end, you’ll find Regula's summary:

```
  "summary": {
    "filepaths": [
      "dev_network/main.tf"
    ],
    "rule_results": {
      "FAIL": 1,
      "PASS": 5,
      "WAIVED": 0
    },
    "severities": {
      "Critical": 0,
      "High": 1,
      "Informational": 0,
      "Low": 0,
      "Medium": 0,
      "Unknown": 0
    }
  }
}
```

This shows us that our Terraform IaC failed 1 rule and passed 5. The rule that failed was of high severity. Scroll back up and we can see exactly which rule failed:

```
    {
      "controls": [
        "CIS-Azure_v1.1.0_6.2",
        "CIS-Azure_v1.3.0_6.2"
      ],
      "filepath": "dev_network/main.tf",
      "input_type": "tf",
      "provider": "azurerm",
      "resource_id": "azurerm_network_security_group.devnsg",
      "resource_type": "azurerm_network_security_group",
      "rule_description": "Virtual Network security groups should not permit ingress from '0.0.0.0/0' to TCP/UDP port 22 (SSH). The potential security problem with using SSH over the internet is that attackers can use various brute force techniques to gain access to Azure Virtual Machines. Once the attackers gain access, they can use a virtual machine as a launch point for compromising other machines on the Azure Virtual Network or even attack networked devices outside of Azure.",
      "rule_id": "FG_R00191",
      "rule_message": "",
      "rule_name": "tf_azurerm_network_security_group_no_inbound_22",
      "rule_result": "FAIL",
      "rule_severity": "High",
      "rule_summary": "Network security group rules should not permit ingress from '0.0.0.0/0' to port 22 (SSH)",
      "rule_remediation_doc": "https://docs.fugue.co/FG_R00191.html",
      "source_location": [
        {
          "path": "dev_network/main.tf",
          "line": 25,
          "column": 1
        }
      ]
    },
```

As expected, Regula caught the security vulnerability present in the Terraform! The rule [`tf_azurerm_network_security_group_no_inbound_22`](https://github.com/fugue/regula/blob/master/rego/rules/tf/azurerm/network/security_group_no_inbound_22.rego) (“Network security group rules should not permit ingress from ‘0.0.0.0/0’ to port 22 (SSH)”) failed because port 22 is open to the world in the dev-nsg network security group. As a result, the build failed, and we see that reflected in our branch and PR tests.

## Fix the build!

Since Regula has reported all of the policies our IaC has violated, we can start remediating the violations.

Open up [`dev_network/main.tf`](https://github.com/fugue/regula-travis-example/blob/main/dev_network/main.tf) in your code editor and change [**line 39**](https://github.com/fugue/regula-travis-example/blob/main/dev_network/main.tf#L39) to use `10.0.0.0/16` instead of `0.0.0.0/0` – it should look like this:

```
    source_address_prefixes     = ["10.0.0.0/16"]
```

Why did we make this change? Our virtual network uses the CIDR range `10.0.0.0/16`, so by setting the source address prefix to this CIDR range, only members of the virtual network can access the NSG.

Now, commit and push your changes:

```
git add dev_network/main.tf
git commit -m "Restrict access to port 22"
git push
```

Return to the PR and you’ll see Travis kicking off another branch build and PR build. View the details in Travis to see the results of Regula’s tests on the updated IaC. This time, all tests pass.

We can confirm this in Regula's summary in the build log:

```
  "summary": {
    "filepaths": [
      "dev_network/main.tf"
    ],
    "rule_results": {
      "FAIL": 0,
      "PASS": 6,
      "WAIVED": 0
    },
    "severities": {
      "Critical": 0,
      "High": 0,
      "Informational": 0,
      "Low": 0,
      "Medium": 0,
      "Unknown": 0
    }
  }
}
```

Pat yourself on the back! In this tutorial, you’ve accomplished the following things:

- You integrated Regula with Travis CI.
- You kicked off a Travis build that failed Regula’s tests due to a security vulnerability.
- You remediated the security vulnerability to make the build pass Regula’s tests.

## Next steps

Want to learn more about Regula? See our [GitHub repo](https://www.github.com/fugue/regula) and [documentation](https://regula.dev). Regula evaluates Terraform HCL, Terraform plan JSON, and CloudFormation YAML/JSON templates for security and compliance. Regula also supports waivers, custom rules, enabling/disabling rules, and more.