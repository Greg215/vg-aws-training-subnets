# terraform-aws-subnets 

Terraform module to provision public and private [`subnets`](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Subnets.html) in an existing [`VPC`](https://aws.amazon.com/vpc)

__Note:__ this module is intended for use with an existing VPC and existing Internet Gateway.

---

## Usage

```hcl
module "subnets" {
  source              = "../subnet"
  vpc_id              = "vpc-XXXXXXXX" #it should pass from VPC module
  igw_id              = "igw-XXXXXXXX" #it should take from VPC module in our case
  cidr_block          = "10.0.0.0/16"  #it should take from VPC module
  availability_zones  = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"] #it can also get by data AZ module
}
```

## Subnet calculation logic

`terraform-aws-dynamic-subnets` creates a set of subnets based on `${var.cidr_block}` input and number of Availability Zones in the region.

For subnet set calculation, the module uses Terraform interpolation

[cidrsubnet](https://www.terraform.io/docs/configuration/interpolation.html#cidrsubnet-iprange-newbits-netnum-).


```
${
  cidrsubnet(
  signum(length(var.cidr_block)) == 1 ?
  var.cidr_block : data.aws_vpc.default.cidr_block,
  ceil(log(length(data.aws_availability_zones.available.names) * 2, 2)),
  count.index)
}
```


1. Use `${var.cidr_block}` input (if specified) or
   use a VPC CIDR block `data.aws_vpc.default.cidr_block` (e.g. `10.0.0.0/16`)
2. Get number of available AZ in the region (e.g. `length(data.aws_availability_zones.available.names)`)
3. Calculate `newbits`. `newbits` number specifies how many subnets
   be the CIDR block (input or VPC) will be divided into. `newbits` is the number of `binary digits`.

    Example:

    `newbits = 1` - 2 subnets are available (`1 binary digit` allows to count up to `2`)

    `newbits = 2` - 4 subnets are available (`2 binary digits` allows to count up to `4`)

    `newbits = 3` - 8 subnets are available (`3 binary digits` allows to count up to `8`)

    etc.

    1. We know, that we have `6` AZs in a `us-east-1` region (see step 2).
    2. We need to create `1 public` subnet and `1 private` subnet in each AZ,
       thus we need to create `12 subnets` in total (`6` AZs * (`1 public` + `1 private`)).
    3. We need `4 binary digits` for that ( 2<sup>4</sup> = 16 ).
       In order to calculate the number of `binary digits` we should use `logarithm`
       function. We should use `base 2` logarithm because decimal numbers
       can be calculated as `powers` of binary number.
       See [Wiki](https://en.wikipedia.org/wiki/Binary_number#Decimal)
       for more details

       Example:

       For `12 subnets` we need `3.58` `binary digits` (log<sub>2</sub>12)

       For `16 subnets` we need `4` `binary digits` (log<sub>2</sub>16)

       For `7 subnets` we need `2.81` `binary digits` (log<sub>2</sub>7)

       etc.
    4. We can't use fractional values to calculate the number of `binary digits`.
       We can't round it down because smaller number of `binary digits` is
       insufficient to represent the required subnets.
       We round it up. See [ceil](https://www.terraform.io/docs/configuration/interpolation.html#ceil-float-).

       Example:

       For `12 subnets` we need `4` `binary digits` (ceil(log<sub>2</sub>12))

       For `16 subnets` we need `4` `binary digits` (ceil(log<sub>2</sub>16))

       For `7 subnets` we need `3` `binary digits` (ceil(log<sub>2</sub>7))

       etc.

    5. Assign private subnets according to AZ number (we're using `count.index` for that).
    6. Assign public subnets according to AZ number but with a shift according to the number of AZs in the region (see step 2)

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| availability_zones | List of Availability Zones where subnets will be created | list(string) | - | yes |
| cidr_block | Base CIDR block which will be divided into subnet CIDR blocks (e.g. `10.0.0.0/16`) | string | - | yes |
| igw_id | Internet Gateway ID the public route table will point to (e.g. `igw-9c26a123`) | string | - | yes |
| map_public_ip_on_launch | Instances launched into a public subnet should be assigned a public IP address | bool | `true` | no |
| max_subnet_count | Sets the maximum amount of subnets to deploy. 0 will deploy a subnet for every provided availablility zone (in `availability_zones` variable) within the region | string | `0` | no |
| name | Name of the subnets that will be created | string | `` | no |
| nat_gateway_enabled | Flag to enable/disable NAT Gateways to allow servers in the private subnets to access the Internet | bool | `true` | no |
| nat_instance_enabled | Flag to enable/disable NAT Instances to allow servers in the private subnets to access the Internet | bool | `false` | no |
| nat_instance_type | NAT Instance type | string | `t3.micro` | no |
| private_network_acl_id | Network ACL ID that will be added to private subnets. If empty, a new ACL will be created | string | `` | no |
| private_subnets_additional_tags | Additional tags to be added to private subnets | map(string) | `<map>` | no |
| public_network_acl_id | Network ACL ID that will be added to public subnets. If empty, a new ACL will be created | string | `` | no |
| public_subnets_additional_tags | Additional tags to be added to public subnets | map(string) | `<map>` | no |
| subnet_type_tag_key | Key for subnet type tag to provide information about the type of subnets, e.g. `cpco.io/subnet/type=private` or `cpco.io/subnet/type=public` | string | `cpco.io/subnet/type` | no |
| subnet_type_tag_value_format | This is using the format interpolation symbols to allow the value of the subnet_type_tag_key to be modified. | string | `%s` | no |
| tags | Additional tags to apply to all resources that use this label module | map(string) | `<map>` | no |
| vpc_default_route_table_id | Default route table for public subnets. If not set, will be created. (e.g. `rtb-f4f0ce12`) | string | `` | no |
| vpc_id | VPC ID where subnets will be created (e.g. `vpc-aceb2723`) | string | - | yes |

## Outputs

| Name | Description |
|------|-------------|
| availability_zones | List of Availability Zones where subnets were created |
| nat_gateway_ids | IDs of the NAT Gateways created |
| nat_instance_ids | IDs of the NAT Instances created |
| private_route_table_ids | IDs of the created private route tables |
| private_subnet_cidrs | CIDR blocks of the created private subnets |
| private_subnet_ids | IDs of the created private subnets |
| public_route_table_ids | IDs of the created public route tables |
| public_subnet_cidrs | CIDR blocks of the created public subnets |
| public_subnet_ids | IDs of the created public subnets |
