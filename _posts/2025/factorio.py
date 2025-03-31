import random

RECIPE = {
    #
    'red_green_pack': {
        'time': 1,
        'red_pack': 1,
        'green_pack': 1,
        'src': 'lab',
    },
    #
    'red_pack': {
        'time': 5,
        'copper': 1,
        'gear': 1,
    },
    'green_pack': {
        'time': 6,
        'inserter': 1,
        'belt': 1,
    },
    # factory
    'belt': {
        'time': .5,
        'gear': 1,
        'iron': 1,
    },
    'inserter': {
        'time': .5,
        'iron': 4,
        'circuit': 1,
        'gear': 1,
        'copper': 1.5,
    },
    'engine': {
        'time': 10,
        'pipe': 2,
        'steel': 1,
        'gear': 1,
        'src': 'machine',
    },
    'steel': {
        'iron': 1,
        'time': .5,
        'src': 'furnace',
    },
    'gear': {
        'iron': 2,
        'time': .5,
    },
    'circuit': {
        'time': .5,
        'copper_cable': 3,
        'iron': 1,
    },
    'pipe': {
        'iron': 1,
        'time': .5,
    },
    # furnace
    'iron': {
        'time': 3,
        'iron_ore': 1,
        'src': 'furnace',
    },
    'copper': {
        'time': 3,
        'copper_ore': 1,
        'src': 'furnace',
    },
    # drill
    'iron_ore': {
        'time': '.3',
        'src': 'drill',
    },
    'copper_ore': {
        'time': '.3',
        'src': 'drill',
    },
}

def get_factory_name(item):
    src = RECIPE[item].get("src", 'machine')
    return f"{src}_{item}"


def get_dep(item, amount=1) -> dict[str, int]:
    """calculate single item requirements"""
    recipe = RECIPE.get(item)
    if not recipe:
        return {item: amount}
    from collections import Counter
    result = Counter()
    #
    factory = get_factory_name(item)
    # num_in = len([k for k in recipe if k not in ('src', 'time')])
    result[factory] += amount
    result[f"{factory}_time"] += recipe['time'] * amount
    result[f"{factory}_unit_speed"] += 1 / recipe['time']
    #
    for need, need_amount in recipe.items():
        if need == 'src':
            continue
        # item dep
        result[f"{item}_{need}"] += need_amount * amount
        # raw dep
        for k, v in get_dep(need).items():
            result[k] += v * need_amount
    return dict(result)


def optimize_for(item, result):
    """avoid single item production starvation"""
    item_time = [v for k, v in result.items() if k.endswith(f"{item}_unit_speed")][0]
    items_time = [(k, v) for k, v in result.items() if k.endswith("_unit_speed")]
    for k, k_item_time in items_time:
        entry = k.removesuffix('_unit_speed')
        import math
        num = math.ceil(k_item_time / item_time)
        result[f"num_{entry}"] = num
        result[f"produce_speed_{entry}"] = num * result[f"{entry}_unit_speed"]
    # TODO consume_speed


def print_result(result):
    for k, v in sorted(result.items()):
        print(k, v)


def test_misc():
    result = get_dep('engine')
    optimize_for('engine', result)
    print_result(result)


def produced_by(item):
    recipe = RECIPE.get(item)
    if not recipe:
        return []
    return [x for x in recipe if x not in ('src', 'time')]


def decide_order(item):
    ret = [item]
    need_items = produced_by(item)
    random.shuffle(need_items)  # TODO
    ret.extend(need_items)
    for need_item in need_items:
        ret.extend(decide_order(need_item))
    return uniq(ret)


def get_distance(items: list):
    dis = 0
    for i, item in enumerate(items):
        for need_item in produced_by(item):
            dis += items[i + 1:].index(need_item)
    return dis


def uniq(l):
    r = []
    for i, x in enumerate(l):
        if x in l[i + 1:]:
            continue
        r.append(x)
    return r


def merge(l1, l2):
    choice1 = uniq(l1 + l2)
    choice2 = uniq(l2 + l1)
    if get_distance(choice1) > get_distance(choice2):
        return choice2
    return choice1


def test_decide_order():
    print()
    l1 = decide_order('red_pack')
    print_line(l1)
    l2 = decide_order('green_pack')
    print_line(l2)
    l3 = merge(l1, l2)
    print_line(l3)
    print_line(sort_by_type(l3))
    l = decide_order('red_green_pack')
    print_line(l)
    print_line(sort_by_type(l))


def print_line(l):w
    print("|".join(l))
    print(len(l), get_distance(l))


def sort_by_type(l):
    def fun_key(a):
        if a.endswith("_ore"):
            return 0
        if a.endswith("_pack"):
            return -2
        return -1

    return sorted(l, key=fun_key)