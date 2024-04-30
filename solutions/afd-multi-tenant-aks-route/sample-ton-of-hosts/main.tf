data "azurerm_resource_group" "res-0" {
  name = "rg-flying-yeti-1"
}

data "azurerm_cdn_frontdoor_profile" "res-5" {
  name                     = "afd-rg-flying-yeti-1"
  resource_group_name      = data.azurerm_resource_group.res-0.name
}
resource "azurerm_cdn_frontdoor_endpoint" "res-6" {
  cdn_frontdoor_profile_id = data.azurerm_cdn_frontdoor_profile.res-5.id
  name                     = "labeastusafd"
}

module "ruleset2" {
  source = "./modules/ruleset"

  ruleset_name = "ruleset2"
  frontdoor_id = data.azurerm_cdn_frontdoor_profile.res-5.id

  hostname_map = {
    0 = {
      hostnames = [
        "customer1.",
        "customer2.",
        "customer3.",
        "customer5.",
        "customer6.",
        "customer7.",
        "customer9.",
        "customer10.",
        "customer12.",
        "customer13.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    1 = {
      hostnames = [
        "customer14.",
        "customer15.",
        "customer17.",
        "customer18.",
        "customer19.",
        "customer20.",
        "customer23.",
        "customer24.",
        "customer26.",
        "customer27.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    2 = {
      hostnames = [
        "customer29.",
        "customer31.",
        "customer32.",
        "customer39.",
        "customer40.",
        "customer42.",
        "customer44.",
        "customer46.",
        "customer49.",
        "customer50.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    3 = {
      hostnames = [
        "customer53.",
        "customer54.",
        "customer55.",
        "customer57.",
        "customer60.",
        "customer61.",
        "customer64.",
        "customer65.",
        "customer69.",
        "customer71.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    4 = {
      hostnames = [
        "customer72.",
        "customer73.",
        "customer74.",
        "customer75.",
        "customer79.",
        "customer80.",
        "customer81.",
        "customer83.",
        "customer84.",
        "customer87.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    5 = {
      hostnames = [
        "customer88.",
        "customer89.",
        "customer92.",
        "customer99.",
        "customer102.",
        "customer103.",
        "customer104.",
        "customer106.",
        "customer108.",
        "customer109.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    6 = {
      hostnames = [
        "customer111.",
        "customer114.",
        "customer115.",
        "customer120.",
        "customer122.",
        "customer124.",
        "customer125.",
        "customer127.",
        "customer131.",
        "customer132.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    7 = {
      hostnames = [
        "customer134.",
        "customer136.",
        "customer140.",
        "customer144.",
        "customer145.",
        "customer149.",
        "customer151.",
        "customer153.",
        "customer154.",
        "customer155.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    8 = {
      hostnames = [
        "customer159.",
        "customer161.",
        "customer162.",
        "customer163.",
        "customer164.",
        "customer165.",
        "customer168.",
        "customer169.",
        "customer171.",
        "customer173.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    9 = {
      hostnames = [
        "customer175.",
        "customer176.",
        "customer180.",
        "customer181.",
        "customer182.",
        "customer183.",
        "customer184.",
        "customer185.",
        "customer188.",
        "customer189.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    10 = {
      hostnames = [
        "customer190.",
        "customer191.",
        "customer193.",
        "customer194.",
        "customer195.",
        "customer196.",
        "customer197.",
        "customer200.",
        "customer203.",
        "customer206.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    11 = {
      hostnames = [
        "customer208.",
        "customer209.",
        "customer210.",
        "customer211.",
        "customer217.",
        "customer219.",
        "customer225.",
        "customer226.",
        "customer228.",
        "customer229.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    12 = {
      hostnames = [
        "customer232.",
        "customer235.",
        "customer236.",
        "customer237.",
        "customer238.",
        "customer240.",
        "customer243.",
        "customer244.",
        "customer246.",
        "customer247.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    13 = {
      hostnames = [
        "customer250.",
        "customer254.",
        "customer255.",
        "customer260.",
        "customer261.",
        "customer267.",
        "customer272.",
        "customer274.",
        "customer275.",
        "customer277.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    14 = {
      hostnames = [
        "customer279.",
        "customer281.",
        "customer284.",
        "customer285.",
        "customer286.",
        "customer287.",
        "customer288.",
        "customer289.",
        "customer291.",
        "customer293.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    15 = {
      hostnames = [
        "customer295.",
        "customer297.",
        "customer298.",
        "customer299.",
        "customer304.",
        "customer305.",
        "customer308.",
        "customer310.",
        "customer312.",
        "customer313.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    16 = {
      hostnames = [
        "customer315.",
        "customer318.",
        "customer319.",
        "customer320.",
        "customer325.",
        "customer328.",
        "customer330.",
        "customer331.",
        "customer333.",
        "customer334.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    17 = {
      hostnames = [
        "customer335.",
        "customer337.",
        "customer338.",
        "customer340.",
        "customer342.",
        "customer343.",
        "customer345.",
        "customer346.",
        "customer347.",
        "customer348.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    18 = {
      hostnames = [
        "customer350.",
        "customer353.",
        "customer354.",
        "customer355.",
        "customer356.",
        "customer360.",
        "customer361.",
        "customer362.",
        "customer363.",
        "customer364.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    19 = {
      hostnames = [
        "customer367.",
        "customer368.",
        "customer371.",
        "customer374.",
        "customer376.",
        "customer378.",
        "customer379.",
        "customer380.",
        "customer382.",
        "customer383.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    20 = {
      hostnames = [
        "customer384.",
        "customer385.",
        "customer386.",
        "customer388.",
        "customer389.",
        "customer393.",
        "customer394.",
        "customer395.",
        "customer405.",
        "customer409.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    21 = {
      hostnames = [
        "customer411.",
        "customer412.",
        "customer413.",
        "customer418.",
        "customer420.",
        "customer422.",
        "customer424.",
        "customer425.",
        "customer426.",
        "customer430.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    22 = {
      hostnames = [
        "customer432.",
        "customer433.",
        "customer434.",
        "customer435.",
        "customer437.",
        "customer440.",
        "customer441.",
        "customer442.",
        "customer443.",
        "customer444.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    23 = {
      hostnames = [
        "customer445.",
        "customer451.",
        "customer452.",
        "customer453.",
        "customer457.",
        "customer459.",
        "customer461.",
        "customer463.",
        "customer464.",
        "customer467.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    24 = {
      hostnames = [
        "customer468.",
        "customer469.",
        "customer470.",
        "customer471.",
        "customer473.",
        "customer474.",
        "customer477.",
        "customer478.",
        "customer479.",
        "customer480.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    25 = {
      hostnames = [
        "customer485.",
        "customer488.",
        "customer493.",
        "customer494.",
        "customer496.",
        "customer499.",
        "customer500.",
        "customer501.",
        "customer502.",
        "customer504.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    26 = {
      hostnames = [
        "customer505.",
        "customer506.",
        "customer508.",
        "customer512.",
        "customer515.",
        "customer518.",
        "customer528.",
        "customer531.",
        "customer534.",
        "customer535.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    27 = {
      hostnames = [
        "customer536.",
        "customer539.",
        "customer540.",
        "customer541.",
        "customer543.",
        "customer544.",
        "customer545.",
        "customer547.",
        "customer548.",
        "customer549.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    28 = {
      hostnames = [
        "customer550.",
        "customer553.",
        "customer554.",
        "customer556.",
        "customer557.",
        "customer558.",
        "customer559.",
        "customer560.",
        "customer561.",
        "customer562.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    29 = {
      hostnames = [
        "customer563.",
        "customer564.",
        "customer565.",
        "customer566.",
        "customer569.",
        "customer570.",
        "customer573.",
        "customer575.",
        "customer577.",
        "customer579.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    30 = {
      hostnames = [
        "customer582.",
        "customer588.",
        "customer589.",
        "customer598.",
        "customer601.",
        "customer602.",
        "customer604.",
        "customer605.",
        "customer607.",
        "customer608.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    31 = {
      hostnames = [
        "customer609.",
        "customer610.",
        "customer612.",
        "customer614.",
        "customer616.",
        "customer618.",
        "customer623.",
        "customer626.",
        "customer627.",
        "customer628.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    32 = {
      hostnames = [
        "customer629.",
        "customer633.",
        "customer635.",
        "customer636.",
        "customer637.",
        "customer640.",
        "customer643.",
        "customer644.",
        "customer645.",
        "customer646.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    33 = {
      hostnames = [
        "customer649.",
        "customer651.",
        "customer653.",
        "customer657.",
        "customer658.",
        "customer660.",
        "customer662.",
        "customer664.",
        "customer665.",
        "customer666.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    34 = {
      hostnames = [
        "customer667.",
        "customer668.",
        "customer671.",
        "customer673.",
        "customer675.",
        "customer678.",
        "customer679.",
        "customer680.",
        "customer682.",
        "customer684.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    35 = {
      hostnames = [
        "customer686.",
        "customer688.",
        "customer690.",
        "customer695.",
        "customer697.",
        "customer698.",
        "customer699.",
        "customer700.",
        "customer703.",
        "customer707.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    36 = {
      hostnames = [
        "customer709.",
        "customer711.",
        "customer712.",
        "customer716.",
        "customer717.",
        "customer720.",
        "customer722.",
        "customer724.",
        "customer726.",
        "customer727.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    37 = {
      hostnames = [
        "customer728.",
        "customer729.",
        "customer730.",
        "customer731.",
        "customer732.",
        "customer733.",
        "customer734.",
        "customer735.",
        "customer736.",
        "customer737.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    38 = {
      hostnames = [
        "customer739.",
        "customer740.",
        "customer741.",
        "customer743.",
        "customer745.",
        "customer746.",
        "customer750.",
        "customer754.",
        "customer760.",
        "customer761.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    39 = {
      hostnames = [
        "customer763.",
        "customer764.",
        "customer765.",
        "customer766.",
        "customer767.",
        "customer768.",
        "customer770.",
        "customer771.",
        "customer774.",
        "customer776.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    40 = {
      hostnames = [
        "customer778.",
        "customer779.",
        "customer780.",
        "customer783.",
        "customer785.",
        "customer786.",
        "customer787.",
        "customer790.",
        "customer793.",
        "customer794.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    41 = {
      hostnames = [
        "customer798.",
        "customer799.",
        "customer802.",
        "customer809.",
        "customer810.",
        "customer814.",
        "customer815.",
        "customer818.",
        "customer819.",
        "customer820.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    42 = {
      hostnames = [
        "customer822.",
        "customer826.",
        "customer829.",
        "customer834.",
        "customer835.",
        "customer837.",
        "customer840.",
        "customer843.",
        "customer845.",
        "customer849.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    43 = {
      hostnames = [
        "customer851.",
        "customer855.",
        "customer856.",
        "customer857.",
        "customer858.",
        "customer860.",
        "customer861.",
        "customer865.",
        "customer870.",
        "customer871.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    44 = {
      hostnames = [
        "customer872.",
        "customer873.",
        "customer877.",
        "customer878.",
        "customer879.",
        "customer882.",
        "customer883.",
        "customer887.",
        "customer888.",
        "customer889.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    45 = {
      hostnames = [
        "customer891.",
        "customer892.",
        "customer894.",
        "customer895.",
        "customer896.",
        "customer901.",
        "customer902.",
        "customer903.",
        "customer904.",
        "customer906.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    46 = {
      hostnames = [
        "customer908.",
        "customer909.",
        "customer910.",
        "customer914.",
        "customer919.",
        "customer920.",
        "customer921.",
        "customer926.",
        "customer928.",
        "customer929.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    47 = {
      hostnames = [
        "customer930.",
        "customer931.",
        "customer932.",
        "customer933.",
        "customer934.",
        "customer937.",
        "customer938.",
        "customer940.",
        "customer941.",
        "customer942.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    48 = {
      hostnames = [
        "customer943.",
        "customer944.",
        "customer948.",
        "customer950.",
        "customer951.",
        "customer952.",
        "customer953.",
        "customer954.",
        "customer956.",
        "customer957.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    49 = {
      hostnames = [
        "customer960.",
        "customer964.",
        "customer966.",
        "customer967.",
        "customer968.",
        "customer969.",
        "customer971.",
        "customer974.",
        "customer976.",
        "customer981.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    50 = {
      hostnames = [
        "customer985.",
        "customer987.",
        "customer989.",
        "customer990.",
        "customer994.",
        "customer995.",
        "customer996.",
        "customer997.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
  }
}

module "ruleset1" {
  source = "./modules/ruleset"

  ruleset_name = "ruleset1"
  frontdoor_id = data.azurerm_cdn_frontdoor_profile.res-5.id
  hostname_map = {
    0 = {
      hostnames = [
        "customer0.",
        "customer4.",
        "customer8.",
        "customer11.",
        "customer16.",
        "customer21.",
        "customer22.",
        "customer25.",
        "customer28.",
        "customer30.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    1 = {
      hostnames = [
        "customer33.",
        "customer34.",
        "customer35.",
        "customer36.",
        "customer37.",
        "customer38.",
        "customer41.",
        "customer43.",
        "customer45.",
        "customer47.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    2 = {
      hostnames = [
        "customer48.",
        "customer51.",
        "customer52.",
        "customer56.",
        "customer58.",
        "customer59.",
        "customer62.",
        "customer63.",
        "customer66.",
        "customer67.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    3 = {
      hostnames = [
        "customer68.",
        "customer70.",
        "customer76.",
        "customer77.",
        "customer78.",
        "customer82.",
        "customer85.",
        "customer86.",
        "customer90.",
        "customer91.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    4 = {
      hostnames = [
        "customer93.",
        "customer94.",
        "customer95.",
        "customer96.",
        "customer97.",
        "customer98.",
        "customer100.",
        "customer101.",
        "customer105.",
        "customer107.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    5 = {
      hostnames = [
        "customer110.",
        "customer112.",
        "customer113.",
        "customer116.",
        "customer117.",
        "customer118.",
        "customer119.",
        "customer121.",
        "customer123.",
        "customer126.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    6 = {
      hostnames = [
        "customer128.",
        "customer129.",
        "customer130.",
        "customer133.",
        "customer135.",
        "customer137.",
        "customer138.",
        "customer139.",
        "customer141.",
        "customer142.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    7 = {
      hostnames = [
        "customer143.",
        "customer146.",
        "customer147.",
        "customer148.",
        "customer150.",
        "customer152.",
        "customer156.",
        "customer157.",
        "customer158.",
        "customer160.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    8 = {
      hostnames = [
        "customer166.",
        "customer167.",
        "customer170.",
        "customer172.",
        "customer174.",
        "customer177.",
        "customer178.",
        "customer179.",
        "customer186.",
        "customer187.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    9 = {
      hostnames = [
        "customer192.",
        "customer198.",
        "customer199.",
        "customer201.",
        "customer202.",
        "customer204.",
        "customer205.",
        "customer207.",
        "customer212.",
        "customer213.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    10 = {
      hostnames = [
        "customer214.",
        "customer215.",
        "customer216.",
        "customer218.",
        "customer220.",
        "customer221.",
        "customer222.",
        "customer223.",
        "customer224.",
        "customer227.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    11 = {
      hostnames = [
        "customer230.",
        "customer231.",
        "customer233.",
        "customer234.",
        "customer239.",
        "customer241.",
        "customer242.",
        "customer245.",
        "customer248.",
        "customer249.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    12 = {
      hostnames = [
        "customer251.",
        "customer252.",
        "customer253.",
        "customer256.",
        "customer257.",
        "customer258.",
        "customer259.",
        "customer262.",
        "customer263.",
        "customer264.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    13 = {
      hostnames = [
        "customer265.",
        "customer266.",
        "customer268.",
        "customer269.",
        "customer270.",
        "customer271.",
        "customer273.",
        "customer276.",
        "customer278.",
        "customer280.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    14 = {
      hostnames = [
        "customer282.",
        "customer283.",
        "customer290.",
        "customer292.",
        "customer294.",
        "customer296.",
        "customer300.",
        "customer301.",
        "customer302.",
        "customer303.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    15 = {
      hostnames = [
        "customer306.",
        "customer307.",
        "customer309.",
        "customer311.",
        "customer314.",
        "customer316.",
        "customer317.",
        "customer321.",
        "customer322.",
        "customer323.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    16 = {
      hostnames = [
        "customer324.",
        "customer326.",
        "customer327.",
        "customer329.",
        "customer332.",
        "customer336.",
        "customer339.",
        "customer341.",
        "customer344.",
        "customer349.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    17 = {
      hostnames = [
        "customer351.",
        "customer352.",
        "customer357.",
        "customer358.",
        "customer359.",
        "customer365.",
        "customer366.",
        "customer369.",
        "customer370.",
        "customer372.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    18 = {
      hostnames = [
        "customer373.",
        "customer375.",
        "customer377.",
        "customer381.",
        "customer387.",
        "customer390.",
        "customer391.",
        "customer392.",
        "customer396.",
        "customer397.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    19 = {
      hostnames = [
        "customer398.",
        "customer399.",
        "customer400.",
        "customer401.",
        "customer402.",
        "customer403.",
        "customer404.",
        "customer406.",
        "customer407.",
        "customer408.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    20 = {
      hostnames = [
        "customer410.",
        "customer414.",
        "customer415.",
        "customer416.",
        "customer417.",
        "customer419.",
        "customer421.",
        "customer423.",
        "customer427.",
        "customer428.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    21 = {
      hostnames = [
        "customer429.",
        "customer431.",
        "customer436.",
        "customer438.",
        "customer439.",
        "customer446.",
        "customer447.",
        "customer448.",
        "customer449.",
        "customer450.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    22 = {
      hostnames = [
        "customer454.",
        "customer455.",
        "customer456.",
        "customer458.",
        "customer460.",
        "customer462.",
        "customer465.",
        "customer466.",
        "customer472.",
        "customer475.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    23 = {
      hostnames = [
        "customer476.",
        "customer481.",
        "customer482.",
        "customer483.",
        "customer484.",
        "customer486.",
        "customer487.",
        "customer489.",
        "customer490.",
        "customer491.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    24 = {
      hostnames = [
        "customer492.",
        "customer495.",
        "customer497.",
        "customer498.",
        "customer503.",
        "customer507.",
        "customer509.",
        "customer510.",
        "customer511.",
        "customer513.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    25 = {
      hostnames = [
        "customer514.",
        "customer516.",
        "customer517.",
        "customer519.",
        "customer520.",
        "customer521.",
        "customer522.",
        "customer523.",
        "customer524.",
        "customer525.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    26 = {
      hostnames = [
        "customer526.",
        "customer527.",
        "customer529.",
        "customer530.",
        "customer532.",
        "customer533.",
        "customer537.",
        "customer538.",
        "customer542.",
        "customer546.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    27 = {
      hostnames = [
        "customer551.",
        "customer552.",
        "customer555.",
        "customer567.",
        "customer568.",
        "customer571.",
        "customer572.",
        "customer574.",
        "customer576.",
        "customer578.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    28 = {
      hostnames = [
        "customer580.",
        "customer581.",
        "customer583.",
        "customer584.",
        "customer585.",
        "customer586.",
        "customer587.",
        "customer590.",
        "customer591.",
        "customer592.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    29 = {
      hostnames = [
        "customer593.",
        "customer594.",
        "customer595.",
        "customer596.",
        "customer597.",
        "customer599.",
        "customer600.",
        "customer603.",
        "customer606.",
        "customer611.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    30 = {
      hostnames = [
        "customer613.",
        "customer615.",
        "customer617.",
        "customer619.",
        "customer620.",
        "customer621.",
        "customer622.",
        "customer624.",
        "customer625.",
        "customer630.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    31 = {
      hostnames = [
        "customer631.",
        "customer632.",
        "customer634.",
        "customer638.",
        "customer639.",
        "customer641.",
        "customer642.",
        "customer647.",
        "customer648.",
        "customer650.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    32 = {
      hostnames = [
        "customer652.",
        "customer654.",
        "customer655.",
        "customer656.",
        "customer659.",
        "customer661.",
        "customer663.",
        "customer669.",
        "customer670.",
        "customer672.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    33 = {
      hostnames = [
        "customer674.",
        "customer676.",
        "customer677.",
        "customer681.",
        "customer683.",
        "customer685.",
        "customer687.",
        "customer689.",
        "customer691.",
        "customer692.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    34 = {
      hostnames = [
        "customer693.",
        "customer694.",
        "customer696.",
        "customer701.",
        "customer702.",
        "customer704.",
        "customer705.",
        "customer706.",
        "customer708.",
        "customer710.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    35 = {
      hostnames = [
        "customer713.",
        "customer714.",
        "customer715.",
        "customer718.",
        "customer719.",
        "customer721.",
        "customer723.",
        "customer725.",
        "customer738.",
        "customer742.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    36 = {
      hostnames = [
        "customer744.",
        "customer747.",
        "customer748.",
        "customer749.",
        "customer751.",
        "customer752.",
        "customer753.",
        "customer755.",
        "customer756.",
        "customer757.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    37 = {
      hostnames = [
        "customer758.",
        "customer759.",
        "customer762.",
        "customer769.",
        "customer772.",
        "customer773.",
        "customer775.",
        "customer777.",
        "customer781.",
        "customer782.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    38 = {
      hostnames = [
        "customer784.",
        "customer788.",
        "customer789.",
        "customer791.",
        "customer792.",
        "customer795.",
        "customer796.",
        "customer797.",
        "customer800.",
        "customer801.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    39 = {
      hostnames = [
        "customer803.",
        "customer804.",
        "customer805.",
        "customer806.",
        "customer807.",
        "customer808.",
        "customer811.",
        "customer812.",
        "customer813.",
        "customer816.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    40 = {
      hostnames = [
        "customer817.",
        "customer821.",
        "customer823.",
        "customer824.",
        "customer825.",
        "customer827.",
        "customer828.",
        "customer830.",
        "customer831.",
        "customer832.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    41 = {
      hostnames = [
        "customer833.",
        "customer836.",
        "customer838.",
        "customer839.",
        "customer841.",
        "customer842.",
        "customer844.",
        "customer846.",
        "customer847.",
        "customer848.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    42 = {
      hostnames = [
        "customer850.",
        "customer852.",
        "customer853.",
        "customer854.",
        "customer859.",
        "customer862.",
        "customer863.",
        "customer864.",
        "customer866.",
        "customer867.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    43 = {
      hostnames = [
        "customer868.",
        "customer869.",
        "customer874.",
        "customer875.",
        "customer876.",
        "customer880.",
        "customer881.",
        "customer884.",
        "customer885.",
        "customer886.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    44 = {
      hostnames = [
        "customer890.",
        "customer893.",
        "customer897.",
        "customer898.",
        "customer899.",
        "customer900.",
        "customer905.",
        "customer907.",
        "customer911.",
        "customer912.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    45 = {
      hostnames = [
        "customer913.",
        "customer915.",
        "customer916.",
        "customer917.",
        "customer918.",
        "customer922.",
        "customer923.",
        "customer924.",
        "customer925.",
        "customer927.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    46 = {
      hostnames = [
        "customer935.",
        "customer936.",
        "customer939.",
        "customer945.",
        "customer946.",
        "customer947.",
        "customer949.",
        "customer955.",
        "customer958.",
        "customer959.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    47 = {
      hostnames = [
        "customer961.",
        "customer962.",
        "customer963.",
        "customer965.",
        "customer970.",
        "customer972.",
        "customer973.",
        "customer975.",
        "customer977.",
        "customer978.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
    48 = {
      hostnames = [
        "customer979.",
        "customer980.",
        "customer982.",
        "customer983.",
        "customer984.",
        "customer986.",
        "customer988.",
        "customer991.",
        "customer992.",
        "customer993.",
      ],
      origin_group_id = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
    },
  }
}

data "azurerm_cdn_frontdoor_custom_domain" "wildcard" {
  name                = "*.sullivantim.com"
  profile_name        = "afd-rg-flying-yeti-1"
  resource_group_name = data.azurerm_resource_group.res-0.name

}

resource "azurerm_cdn_frontdoor_route" "res-7" {
  cdn_frontdoor_origin_ids        = []
  cdn_frontdoor_custom_domain_ids = [data.azurerm_cdn_frontdoor_custom_domain.wildcard.id]
  cdn_frontdoor_endpoint_id       = data.azurerm_cdn_frontdoor_profile.res-5.id
  cdn_frontdoor_origin_group_id   = data.azurerm_cdn_frontdoor_origin_group.eastus-og.id
  cdn_frontdoor_rule_set_ids      = [module.ruleset1.ruleset_id, module.ruleset2.ruleset_id]
  forwarding_protocol             = "HttpOnly"
  https_redirect_enabled          = false
  name                            = "default-route"
  patterns_to_match               = ["/*"]
  supported_protocols             = ["Http", "Https"]
  depends_on = [
    module.ruleset1
  ]
}

data "azurerm_cdn_frontdoor_origin_group" "eastus-og" {
  name                = "eastus-cluster"
  profile_name        = "afd-rg-flying-yeti-1"
  resource_group_name = data.azurerm_resource_group.res-0.name
}