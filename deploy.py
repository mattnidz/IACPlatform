import os, sys, subprocess, re

old_ami = sys.argv[1] 
new_ami = sys.argv[2] 

# Regex switch out the AMI for the user
def changeAmi(old_ami,new_ami):
    if len(sys.argv) == 3:
        print(f"INFO: Changing dld AMI {old_ami} to new Ami - {new_ami}")
        with open("terraform.tfvars", "r") as sources:
            lines = sources.readlines()
        with open("terraform.tfvars", "w") as sources:
            for line in lines:
                sources.write(re.sub(r"%s"%old_ami, "%s"%new_ami, line))
            sources.close()

# Run the terraform apply through subprocess
def applyTerraform():
    process = subprocess.Popen('terraform apply -input=false -auto-approve', shell=True, cwd=os.getcwd(), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    std_out, std_err = process.communicate()
    if process.returncode != 0:
        err_msg = "%s. Code: %s" % (std_err.strip().decode("utf-8"), process.returncode)
        print(err_msg)
        sys.exit(process.returncode)
    else:
        print(std_out.decode("utf-8"))
    return std_out.rstrip()


def main():
    changeAmi(old_ami,new_ami)
    #print(changeAmi("ami-0394fe9914b475c53","ami-011b3ccf1bd6db744"))
    print("INFO: Running Deployment")
    applyTerraform()


if __name__ == "__main__":
    main()