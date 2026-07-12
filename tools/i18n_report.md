# fructa i18n audit

Hardcoded strings: **59** across **20** files.
en.json keys: **422** · referenced in code: **242**

## A. Hardcoded user-facing strings

### lib/features/learn/lesson_player.dart  (10)
```
  330  widget         kept after tax \u00b7 1 year
  340  widget         you put in
  380  widget         QUICK CHECK
  532  widget         +${lesson.xp}
  543  widget         Lesson complete
  547  widget         Nicely done. Your streak is at $streak.
  576  widget         See ${fund?.name ?? 
  600  widget         Back to path
  617  widget         Back to path
  988  widget         Y${v.toInt()}
```
### lib/features/portfolio/portfolio_page.dart  (7)
```
  171  title          Portfolio
  273  title          Allocation
  280  title          Holdings
  280  trailing       accrued value shown
  305  title          If you keep investing
  922  label          Add your first investment
  928  label          Browse top rates
```
### lib/features/onboarding/appearance_scene.dart  (7)
```
   51  widget         MAKE IT YOURS
   58  widget         Pick your look
   82  widget         Accent
  103  widget         Text size
  110  widget         A
  126  widget         A
  194  widget         Money market · net ${net.toStringAsFixed(2)}%
```
### lib/features/portfolio/manage_holding_sheet.dart  (6)
```
   59  widget         Remove holding?
   67  widget         Cancel
   71  widget         Remove
  140  widget         Balance
  178  widget         Save
  192  widget         Remove
```
### lib/features/markets/widgets/market_context_card.dart  (5)
```
  165  label          MMF avg
  167  label          T-bill 91d
  169  label          Inflation
  177  label          INFLATION
  182  label          91-DAY
```
### lib/features/learn/learn_home_page.dart  (4)
```
  123  widget         Money, decoded
  218  widget         LEVEL ${level + 1} \u00b7 ${titles[level]}
  540  widget         UP NEXT
  620  widget         Lessons are on the way
```
### lib/core/widgets/rows.dart  (2)
```
  291  tooltip        Call
  298  tooltip        WhatsApp
```
### lib/features/insure/insure_motor_page.dart  (2)
```
  405  widget         KES ${_short(_kMinValue)}
  411  widget         KES ${_short(_kMaxValue)}
```
### lib/features/markets/search_overlay.dart  (2)
```
  102  widget         Cancel
  162  widget         Nothing matches \u201c$_q\u201d.
```
### lib/features/markets/widgets/best_fund_hero.dart  (2)
```
  186  widget         BEST RATE
  307  label          Fund rate
```
### lib/features/portfolio/projection_card.dart  (2)
```
   86  label          Monthly top-up
   97  label          Horizon
```
### lib/data/models/insurance_type.dart  (2)
```
   39  label          Motor
   40  label          Travel
```
### lib/main.dart  (1)
```
   50  title          Fructa
```
### lib/core/widgets/in_app_web_page.dart  (1)
```
   93  tooltip        Reload
```
### lib/app/lock_gate.dart  (1)
```
  125  widget         Unlock
```
### lib/features/insure/insurer_detail_page.dart  (1)
```
  184  widget           ${t()}
```
### lib/features/settings/blog_web_page.dart  (1)
```
   93  tooltip        Reload
```
### lib/features/alerts/alerts_page.dart  (1)
```
   40  widget         Alerts
```
### lib/features/markets/filter_sheet.dart  (1)
```
   50  widget         Tax-free only
```
### lib/features/onboarding/alerts_scene.dart  (1)
```
  163  widget         See the markets
```

## B. Keys used in code, absent from en.json (renders blank)

```
some.key
```

## C. Keys in en.json referenced nowhere

```
alerts.empty
alerts.emptyBody
alerts.title
app.name
backup.foundBody
backup.foundBodyFrom
common.cancel
common.done
common.no
common.remove
common.retry
common.save
common.showMore
common.yes
company.agents
company.grossYield
company.holds
company.invest
company.netAfterWht
company.perDayNet
company.position
company.real
company.stat.category
company.stat.currency
company.stat.fee
company.stat.managerAum
company.stat.managerShare
company.stat.minimum
company.stat.ofManagers
company.stat.taxFree
company.stats
company.taxFreeCoupon
company.usdFxNote
company.usdKesEquiv
compare.done
compare.empty
compare.liquidity
compare.matrixHeader
compare.saved
compare.subtitle
compare.title
fundType.balanced
fundType.equity
fundType.fixed_income
fundType.mmf
fundType.special
insure.claims
insure.class.commercial
insure.class.private
insure.class.psv
insure.comingSoon
insure.cover.comprehensive
insure.cover.tpo
insure.dir.kicker
insure.dir.kpi.flagged
insure.dir.kpi.licensed
insure.dir.kpi.rated
insure.dir.searchN
insure.disc.detail
insure.disc.home
insure.disc.motor
insure.disc.travel
insure.excess
insure.from
insure.homeSub
insure.indicativeNote
insure.insurerLiveOne
insure.insurersLive
insure.motor.absent
insure.motor.classFoot
insure.motor.classSub
insure.motor.classTitle
insure.motor.psvEmpty
insure.motor.psvEmptyBody
insure.motorGrid
insure.motorGridOne
insure.motorSub
insure.proof.body
insure.proof.kpi.licensed
insure.proof.kpi.priced
insure.proof.kpi.spread
insure.region.af
insure.region.ea
insure.region.sch
insure.region.ww
insure.review.claimsHolder
insure.review.consent
insure.review.count
insure.review.disclaimer
insure.review.helpful
insure.review.none
insure.review.noneBody
insure.review.pending
insure.review.placeholder
insure.review.reason.abuse
insure.review.reason.false
insure.review.reason.other
insure.review.reason.personal_info
insure.review.reason.spam
insure.review.rejected
insure.review.report
insure.review.reported
insure.review.rules
insure.review.sub
insure.review.submit
insure.review.submitted
insure.review.title
insure.review.write
insure.review.writeSub
insure.soon
insure.soonBadge
insure.sort.benefits
insure.sort.cheapest
insure.sort.value
insure.travelGrid
insure.travelSub
insure.trust.gradeScale
insure.trust.shareFoot
insure.trust.shareOthers
insure.trust.shareSub
insure.trust.shareTitle
insure.trust.timeline
insure.trust.tl.licensed
insure.trust.tl.rated
insure.trust.tl.share
insure.trust.tl.statMgmt
insure.trusted
insure.vehicleValue
insure.why.1
insure.why.2
insure.why.3
insure.why.4
insure.why.sub
insure.why.title
markets.bestMmf
markets.brandDot
markets.insurance.comingSoon
markets.insurance.subtitle
markets.insurance.title
markets.liveSub
markets.news
markets.sort.highestYield
markets.sort.lowestMinimum
markets.sort.taxFree
markets.tab.all
markets.tab.balanced
markets.tab.bonds
markets.tab.dollar
markets.tab.equity
markets.tab.islamic
markets.tab.moneyMarket
markets.tab.reit
markets.tab.sacco
markets.taxFreeBadge
nav.portfolio
nav.settings
onboarding.alertsBody
onboarding.alertsTitle
onboarding.later
onboarding.offBody
onboarding.offTitle
onboarding.onBody
onboarding.onTitle
onboarding.seeMarkets
onboarding.turnOn
portfolio.add.cardSub
portfolio.add.cardSubOne
portfolio.allocation
portfolio.empty
portfolio.netWorth
portfolio.summary
portfolio.title
settings.accent
settings.data
settings.data.soon
settings.learn.soon
settings.mode.dark
settings.mode.light
settings.mode.system
settings.notif.couponsSub
settings.version
```

## D. Duplicate values in en.json

```
'alerts'                           nav.alerts, alerts.title
'all'                              markets.tab.all, insure.dir.all
'balanced'                         fundType.balanced, markets.tab.balanced
'best value'                       insure.filter.value, insure.sort.value
'call'                             company.call, insure.contact.call
'cheapest'                         insure.filter.cheapest, insure.sort.cheapest
'compare'                          markets.sort.compare, compare.title
'done'                             common.done, compare.done
'email'                            company.email, insure.contact.email
'equity'                           fundType.equity, markets.tab.equity
'excess {v}'                       insure.excess, insure.excessShort
'flagged'                          insure.dir.flagged, insure.dir.kpi.flagged
'insurance'                        markets.insurance.title, insure.title
'licensed'                         insure.dir.kpi.licensed, insure.proof.kpi.licensed, insure.trust.licensed
'minimum'                          company.stat.minimum, compare.minimum
'money market'                     fundType.mmf, markets.tab.moneyMarket
'most benefits'                    insure.filter.benefits, insure.sort.benefits
'official site'                    company.officialSite, insure.officialSite
'portfolio'                        nav.portfolio, portfolio.title
'rated'                            insure.dir.kpi.rated, insure.dir.rated
'saved comparisons'                compare.savedTitle, settings.notif.saved
'settings'                         nav.settings, settings.title
'signals'                          company.signals, insure.signals
'talk to an agent'                 company.talkToAgent, insure.talkAgent
'tax-free'                         markets.sort.taxFree, markets.taxFreeBadge, company.stat.taxFree
'website'                          company.website, insure.contact.website
'whatsapp'                         company.whatsapp, insure.contact.whatsapp
'your position'                    company.position, company.yourPosition
```

## E. Locale parity

```
```
