return {
    -- Ice cream ingredients
    ['milk'] = {
        label = 'Milk',
        weight = 500,
        stack = true,
        close = true,
        description = 'Fresh milk'
    },

    ['ice'] = {
        label = 'Ice',
        weight = 100,
        stack = true,
        close = true,
        description = 'Ice cubes'
    },

    -- Ice cream product
    ['icecream'] = {
        label = 'Ice Cream',
        weight = 200,
        stack = true,
        close = true,
        description = 'Delicious homemade ice cream',
        client = {
            status = { hunger = 100000 },
            anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger' },
            prop = { model = 'prop_cs_burger_01', bone = 60309, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
            usetime = 5000,
        }
    },

    -- Taco ingredients
    ['tortilla'] = {
        label = 'Tortilla',
        weight = 100,
        stack = true,
        close = true,
        description = 'Soft tortilla wrap'
    },

    ['meat'] = {
        label = 'Cooked Meat',
        weight = 300,
        stack = true,
        close = true,
        description = 'Seasoned cooked meat'
    },

    ['cheese'] = {
        label = 'Cheese',
        weight = 150,
        stack = true,
        close = true,
        description = 'Shredded cheese'
    },

    ['rice'] = {
        label = 'Rice',
        weight = 200,
        stack = true,
        close = true,
        description = 'Cooked rice'
    },

    -- Taco products
    ['taco'] = {
        label = 'Taco',
        weight = 250,
        stack = true,
        close = true,
        description = 'Delicious street taco',
        client = {
            status = { hunger = 150000 },
            anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger' },
            prop = { model = 'prop_taco_01', bone = 60309, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
            usetime = 6000,
        }
    },

    ['burrito'] = {
        label = 'Burrito',
        weight = 400,
        stack = true,
        close = true,
        description = 'Large burrito stuffed with meat, cheese, and rice',
        client = {
            status = { hunger = 200000 },
            anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger' },
            prop = { model = 'prop_food_bs_burger2', bone = 60309, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
            usetime = 8000,
        }
    }
}

