# Simple Item Levels

Show item levels on:

* The character panel
* The inspect panel
* Loot windows
* The equipment-picker flyout
* Weapons, armor, and artifact relics in bags (built in, bagnon, baggins, inventorian)
* Tooltips (in classic)

I'm open to adding them in more places.

Also shows:

* An upgrade arrow on items in your bags which you can use whose item level is higher than whatever you currently have equipped.
* A soulbound indicator, so you can see whether something is soulbound, bind-on-equip, or warbound-until-equipped
* Missing enchants and gems

### Simple configuration

For a summary of settings:
```/simpleilvl```

To  toggle a place to display item levels:
```/simpleilvl [type]```

...where `type` is `bags`, `character`, or `inspect`.

To disable the upgrade arrow:
```/simpleilvl upgrades```

To change whether the text is colored by item quality or just left white:
```/simpleilvl color```