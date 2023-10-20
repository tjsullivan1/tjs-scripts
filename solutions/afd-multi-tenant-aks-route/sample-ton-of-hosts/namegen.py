import random

origins = ["azurerm_cdn_frontdoor_origin_group.res-12.id", "azurerm_cdn_frontdoor_origin_group.res-15.id"]

customer_list_o1 = []
customer_list_o2 = []

for i in range(1000):
    target = random.choice(origins)
    if target == "azurerm_cdn_frontdoor_origin_group.res-12.id":
        customer_list_o1.append(f'customer{i}.')
    else:
        customer_list_o2.append(f'customer{i}.')

# Split customer_list_o2 into groups of ten
customer_list_o1_groups = [customer_list_o1[i:i+10] for i in range(0, len(customer_list_o1), 10)]

# Split customer_list_o2 into groups of ten
customer_list_o2_groups = [customer_list_o2[i:i+10] for i in range(0, len(customer_list_o2), 10)]

# split list_01_groups into groups of 100
customer_list_o1_groups_max = [customer_list_o1_groups[i:i+100] for i in range(0, len(customer_list_o1_groups), 100)]

# split list_02_groups into groups of 100
customer_list_o2_groups_max = [customer_list_o2_groups[i:i+100] for i in range(0, len(customer_list_o2_groups), 100)]


def write_hostname_list_to_file(filename, customer_list, origin_group):
    with open(filename, 'w') as f:
        f.write('hostname_map = {\n')
        for ruleset in customer_list:
            for rule in ruleset:
                f.write(f'{ruleset.index(rule)} = {{\n')
                f.write('hostnames = [\n')
                
                for customer in rule:
                    f.write(f'"{customer}",\n')

                f.write('],\n')
                f.write(f'origin_group_id = {origin_group}\n')
                f.write('},\n')
        
        f.write('}')

write_hostname_list_to_file('customer_list_o1_groups_max.txt', customer_list_o1_groups_max, 'azurerm_cdn_frontdoor_origin_group.res-12.id')
write_hostname_list_to_file('customer_list_o2_groups_max.txt', customer_list_o2_groups_max, 'azurerm_cdn_frontdoor_origin_group.res-15.id')