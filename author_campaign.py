import json
from pathlib import Path
from copy import deepcopy

ROOT = Path(__file__).resolve().parent / 'outputs' / 'AshenOathTheRoadBetweenCrowns'
def read(name):
    return json.loads((ROOT / 'data' / name).read_text(encoding='utf-8-sig'))
def write(name, value):
    (ROOT / 'data' / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
d = read('dialogue.json')
c = read('campaign_dialogue.json')
q = read('quests.json')

def scene(table, key, greeting, lines, variants=None):
    row = table.setdefault(key, {'name': key.replace('_', ' ').title(), 'actions': []})
    row['greeting'], row['lines'] = greeting, lines
    row['voice'] = []
    row.pop('fallback_text', None)
    row['content_version'] = 2
    if variants is not None:
        row['variants'] = variants
    return row
def variant(priority, conditions, greeting, lines, actions=None):
    result = {'priority': priority, 'conditions': conditions, 'greeting': greeting, 'lines': lines}
    if actions is not None:
        result['actions'] = actions
    return result
def done(quest, objective):
    return {'quest': quest, 'id': objective}
def choice(label, quest='', objective='', flags=None, result='', values=None, conditions=None):
    action = {'label': label, 'type': 'story_choice', 'sets_flags': flags or {}, 'result': result}
    if quest:
        action.update(quest=quest, objective=objective)
        action['conditions'] = {'quest_active': quest, 'objectives_not_done': [done(quest, objective)]}
    if conditions:
        action.setdefault('conditions', {}).update(conditions)
    if values:
        action['adjusts_values'] = values
    return action
def consent(actor, value, line):
    return choice(line, flags={f'witness_consent_{actor}': value}, result=f'The decision is recorded. Nobody else can make it for {actor.title()}.', conditions={'renewal_announced': True, 'flag_unset': f'witness_consent_{actor}'})
def pledge_actions():
    return [choice(label, flags={'kael_pledge': value}, result=result, conditions={'flag_unset': 'kael_pledge'}) for label, value, result in [
        ("I'll stay until the people carrying this can speak safely.", 'protect', 'Kael: I cannot promise nobody gets hurt. I can promise I will not take the coin and leave you to it.'),
        ("I'll stay. We keep a record nobody can close again.", 'account', 'Kael: Copies, names, living witnesses. Not another secret that depends on one person.'),
        ("I'll stay, but you tell me what you are asking me to carry.", 'stay', 'Anwen: That is fair. I should have asked before I put the token in your hand.')]]

scene(d, 'notice_board', 'Three missing on the north road. Bram Kett. Sella Vey. Her son Oren.', [
    'Payment for an account of the missing and proof of what took them. Names held at the Crow Shrine.',
    'A second hand has added: Bram did not abandon a cart while someone needed it. Ask who closed the road.'], [
    variant(50, {'renewal_stopped': True}, 'The order beside the contract has been crossed through. The names remain.', ['Kael: The grain is no longer being held against a signature. Keeping it moving will take more than words.'], []),
    variant(40, {'renewal_announced': True}, 'A Vargan notice covers half the old contract.', ['Protected households must attend the renewal. Grain allotments will be recorded beside their assent.', 'Kael: Hunger does not make an oath freely given.'], []),
    variant(30, {'evidence_report': 'public'}, 'Oren\'s token hangs below the contract. Someone has tied a dry scrap of cloth over it.', ['Kael: They have not taken it down. Somebody is afraid enough to cover it and kind enough to keep it dry.'], []),
    variant(30, {'evidence_report': 'private'}, 'A small note has been added: anyone who saw Bram\'s cart should speak to Anwen.', ['Kael: A private account can still invite a second witness.'], []),
    variant(30, {'evidence_report': 'retained'}, 'The payment remains unclaimed. Beneath it, three empty places for names.', ['Kael: Keeping the token is not the same as keeping them safe.'], [])])
d['notice_board']['actions'][0]['label'] = 'I will find what happened to Bram, Sella, and Oren.'

anwen = scene(d, 'sister_anwen', 'Mind the cup on the step. The man from the south road needs it more than I need a clean floor.', [
    'Kael: I read the road notice. Three missing.',
    'Anwen: Bram drove. Sella had Oren beside her. He left his coat here because the sun was out.',
    'Anwen: They found old wooden tokens where the road was being repaired. Sella asked me to read one. I did.',
    'Kael: What happened when you read it?',
    'Anwen: The candles went out. I sent them away while I found a rite I thought would keep them safe.',
    'Anwen: If you find red thread around black feathers, keep it intact. I tied it. I owe you that much before you go.'])
anwen['variants'] = [
    variant(90, {'renewal_stopped': True}, 'I have put the grain list beside the burial book. No one has to sign one to receive the other.', ['Anwen: I could call that a beginning. It is mostly a table and two people willing to sit at it.', 'Kael: Beginnings usually look smaller when somebody is doing the work.']),
    variant(85, {'witness_consent_anwen': 'refused'}, 'I will give you the register. I am not agreeing to stand in a rite you threatened me into.', ['Kael: The record can speak to facts. It cannot make your promise for you.', 'Anwen: Then you do understand the difference.']),
    variant(80, {'renewal_announced': True}, 'Edric wants my hand on the new seal. He has already counted the households that cannot afford to refuse.', ['Anwen: The old rite borrowed consent from frightened people. That is why it keeps breaking.', 'Kael: Can the Hart be released without making everyone here swear?', 'Anwen: Yes. Someone must freely keep the recovered account. One person can begin. More people can share the work.']),
    variant(50, {'bell_gate_met': True}, 'Three strokes. A burial, a restored name, and a promise that has stopped holding.', ['Anwen: I cut the rope last winter. A novice heard an erased name and walked into the sealed chapel. I found him too late.', 'Kael: You closed it again.', 'Anwen: Yes. I told myself I was buying time. The graves will show what that time cost.'], pledge_actions()),
    variant(40, {'evidence_report': 'private'}, 'That is Oren\'s carving. Turn it over. The older name is beneath his paint.', ['Kael: You sent them out carrying something the shrine had erased.', 'Anwen: I thought new burial thread would quiet it. Someone bound it again with Vargan wire.', 'Kael: The pack is dead. The people hiding this are alive.', 'Anwen: Take your payment if you must. I need help I have no right to order.'], pledge_actions()),
    variant(40, {'evidence_report': 'public'}, 'I saw the token on the board. Rook has moved his bedding from the window.', ['Kael: People needed to know what was on their road.', 'Anwen: Yes. And the people who can explain it need a way to survive being known.', 'Kael: Then we do both. I will not leave the second part to a notice.'], pledge_actions()),
    variant(40, {'evidence_report': 'retained'}, 'Keep your hand closed if you need to. I recognize the shape through your glove.', ['Anwen: Oren painted over a refugee\'s token. Sella wanted the first name restored.', 'Kael: Someone alive tried to take it from the pack.', 'Anwen: Then leaving now would leave a witness carrying something dangerous. I am asking you to stay.'], pledge_actions())]
for action in anwen['actions']:
    if action.get('objective') == 'speak_anwen':
        action['label'] = 'I will follow the cart. Keep his coat here.'
    if action.get('sets_flags', {}).get('anwen_response') == 'report':
        action['adjusts_values'] = {}
anwen['actions'] += [consent('anwen', 'voluntary', 'Will you speak for your own part, without the seal?'), consent('anwen', 'refused', 'Give me the book. I will not demand your oath.')]

mira = scene(d, 'mira', 'Hold the door. Elna is bringing broth, and I have both hands occupied.', [
    'Mira: Toma\'s daughter has a fever. The draught works. The roots it needs grow in the old ash beds.',
    'Kael: Does Toma know where it comes from?',
    'Mira: He knows I can bring the fever down. I have let him think that was the only fact that mattered.',
    'Mira: Sella bought salve for Oren\'s hands. Too much carving. I have one jar she never collected.'], [
    variant(90, {'mira_truth': 'destroyed'}, 'The clean roots take longer to steep. I keep a cold cloth ready between doses.', ['Mira: You did not make the fever disappear by closing the ash bed.', 'Kael: No. Who needs help while the new treatment catches up?', 'Mira: Toma. He has not slept. Bring him the broth before it cools.']),
    variant(90, {'mira_truth': 'confessed'}, 'The jars have their source written on them now. Two families refused. Three asked questions.', ['Mira: I treated all five. Consent would mean little if refusal meant I stopped caring.', 'Kael: What will you say at the assembly?', 'Mira: What I used. What I withheld. What I am changing.']),
    variant(90, {'mira_truth': 'kept'}, 'The fever broke. Toma thanked me. I let him.', ['Mira: There is your immediate result. A child is breathing easier.', 'Kael: And the part he still cannot choose?', 'Mira: Still here. Under the label I have not written.']),
    variant(60, {'bog_core_fate': 'preserved'}, 'The wrapped core shifts toward the names in the book, not toward my instruments.', ['Mira: It is a memory, not a patient who can answer me. I will not call a useful response permission.', 'Kael: Study what is already exposed. Do not open another name without asking the family.']),
    variant(45, {'teeth_supplies_taken': True}, 'Say Oren\'s name at the old stones. Watch the roots before you move closer.', ['Mira: The oil shows where the memory is caught. It does not decide what you should do with it.', 'Kael: And breaking the vessel?', 'Mira: Stops that shape. The memory goes somewhere else. We can defend ourselves without pretending the aftermath is nothing.']),
    variant(40, {'teeth_in_rain_available': True}, 'The chapel register and the roots turned toward the same name.', ['Mira: Oren restored a name on his token. The road\'s concealment could not keep it disordered afterward.', 'Kael: That brought the creatures?', 'Mira: The tokens drew them. The failed binding left the memory loose. Read the register before you face what took it.'])])
for action in mira['actions']:
    if action.get('type') == 'start_quest': action['label'] = 'Show me what the fever draught needs.'
    if action.get('objective') == 'collect_roots':
        action['label'] = 'I brought the roots from the marked bed.'
        action.setdefault('conditions', {})['bitter_roots_collected'] = True
    if action.get('objective') == 'mira_choice':
        value = action['sets_flags']['mira_truth']
        action['sets_flags'].update(mira_truth_known=True, mira_treatment='private' if value == 'kept' else 'consented', witness_consent_mira='refused' if value == 'kept' else 'voluntary')
        if value == 'kept':
            action.update(label='Keep treating quietly until there is an alternative.', result='Mira keeps the ash bed open. The fever falls, but families cannot choose a treatment whose origin remains hidden.')
        else:
            action.update(label='Explain the source. Offer each family another treatment.', result='Mira labels the ash draught and sets clean-root doses beside it. The treatment is slower for those who refuse, and care continues.')
mira['actions'].append(choice('Close the ash bed. Use clean roots and accept the delay.', 'side_bitter_roots', 'mira_choice', {'mira_truth': 'destroyed', 'mira_treatment': 'replacement', 'mira_truth_known': True, 'witness_consent_mira': 'voluntary'}, 'Mira closes the old bed and prepares clean roots. Toma stays through the slower treatment; nobody calls the extra waiting harmless.', conditions={'objectives_done': [done('side_bitter_roots', 'collect_roots')]}))
for action in mira['actions']:
    if action.get('sets_flags', {}).get('witness_consent_mira') == 'voluntary':
        action['result'] += ' Mira freely agrees to explain her own actions at the assembly.'
mira['actions'] += [consent('mira', 'voluntary', 'Will you freely speak to your own use of the ash?'), consent('mira', 'refused', 'Give me your written findings. I will not ask you for an oath.')]

scene(d, 'edric', 'The south granary is open. Tell the guard the sick household goes first.', [
    'Kael: Your seal was wrapped around a child\'s token.',
    'Edric: My men were sent to contain a breach. They came back with empty hands and fewer men.',
    'Edric: I have grain for Greyfen. I do not have a road that will carry it safely.',
    'Kael: And the people who know why?',
    'Edric: Bring their account to the castle. I will show you what another winter requires.'], [
    variant(60, {'renewal_stopped': True}, 'The carts will move without a household seal. I have given the order.', ['Edric: My guards can keep a road open. They cannot make the people on it believe me.', 'Kael: Begin with the first job. The second takes longer.']),
    variant(40, {'renewal_announced': True}, 'You have read the renewal order. You have not watched a hungry house divide its last loaf.', ['Kael: I have watched people be told safety was inside a gate they could not enter.', 'Edric: Then come to the record hall. Argue where the figures are.'])])
for action in d['edric']['actions']:
    if action.get('type') == 'start_quest': action['label'] = 'I will bring the road evidence to your record hall.'
    if action.get('objective') == 'reach_castle': action['label'] = 'Your gate is open. Now show me the records.'

rook = scene(d, 'rook', 'You got the cart moving? Good. I was about to sell him a very expensive push.', [
    'Rook: Bram fixed my axle twice. Charged me once. Claimed he could not afford to be seen with a grateful smuggler.',
    'Kael: You knew the other two?',
    'Rook: Sella asked about the old road. Oren asked whether the crows paid me to follow them.',
    'Rook: The road bends where the old waystone says it should not. I have a map. I also have a room somebody can find.'], [
    variant(90, {'rook_disclosure': 'public'}, 'They copied the map with my family mark still on it. A guard came to my door.', ['Rook: You needed a witness. You got a target as well.', 'Kael: I will keep a way out open.', 'Rook: That was meant to be the promise before you put my name up.']),
    variant(90, {'rook_disclosure': 'protected'}, 'I copied the route without the houses. The families know who has the original.', ['Rook: I will tell the assembly what I saw. They do not need my grandmother\'s bedroom to believe it.', 'Kael: You choose what is yours to share.', 'Rook: There. A sentence I could get used to.']),
    variant(90, {'rook_disclosure': 'erased'}, 'I can still walk the route. I will not make another map for you.', ['Rook: Destroying the copy kept Vargan from using it. It kept the next refugee from using it too.', 'Kael: I can carry the route in the record without your family mark.', 'Rook: Then learn it properly.']),
    variant(60, {'renewal_announced': True}, 'The guard asked where my grandmother lived. Said he was checking who deserved protection.', ['Rook: My family kept names because the shrine would not. That does not make us willing to be nailed to a board.', 'Kael: I promised to stay with the people carrying this.', 'Rook: Then stay where they can reach you. The false waystone is a good start.'])])
for action in rook['actions']:
    if action.get('objective') == 'map_choice':
        if action['sets_flags']['rook_map_fate'] == 'preserved':
            action.update(label='Copy the route. Keep the families\' homes private.', result='Rook marks a usable road without family addresses. He agrees to speak to the route under protection.')
            action['sets_flags'].update(rook_disclosure='protected', witness_consent_rook='voluntary')
        else:
            action.update(label='Destroy the map. Keep the route between us.', result='The paper burns. The road remains in Rook\'s memory, but no stranger can follow a copy now.')
            action['sets_flags'].update(rook_disclosure='erased', witness_consent_rook='refused')
rook['actions'].append(choice('Publish the marked map so everyone can challenge Vargan.', 'side_rooks_map', 'map_choice', {'rook_map_fate': 'preserved', 'rook_disclosure': 'public', 'witness_consent_rook': 'refused'}, 'The route becomes public evidence. Rook takes his bedding from the window; he did not consent to exposing his family.', {'greyfen_fear': 1}, {'objectives_done': [done('side_rooks_map', 'walk_false_road')]}))

elna = scene(d, 'widow_elna', 'Harl used to warm my shoes by the fire. Burned one once. Hid it for a week.', [
    'Elna: You can know that and still hear what I ask next.',
    'Elna: His grave bell rings with the rope cut. He helped close Greyfen\'s gate in the war. I told our children he held it for their safety.',
    'Kael: Did he ever speak about the people outside?',
    'Elna: He would stop setting the table when it rained. Find what he left. Do not decide for me that love makes me unable to hear it.'], [
    variant(80, {'widow_truth': 'told'}, 'I told the children he loved us. Then I told them who stood outside the gate.', ['Elna: My daughter asked if both were true. I said yes.', 'Kael: Will you speak at the assembly?', 'Elna: About what I know. His victims do not need me performing my grief over their names.']),
    variant(80, {'widow_truth': 'comforted'}, 'I put the bell in the drawer. It is quieter in there.', ['Elna: You offered me a gentler account. I heard what you left out.', 'Kael: The record remains.', 'Elna: Then leave it where the children can find it when they ask.']),
    variant(80, {'widow_truth': 'private'}, 'The children have the account. I will not read it in the square.', ['Elna: You may name what Harl did. You may not use my kitchen as proof I have forgiven it.', 'Kael: Your grief stays yours.'])])
for action in elna['actions']:
    if action.get('type') == 'start_quest': action['label'] = 'I will hear what the bell is carrying.'
    if action.get('objective') == 'widow_choice':
        truth = action['sets_flags']['widow_truth'] == 'told'
        action.update(label='Give Elna the whole account, and let her decide to speak.' if truth else 'Offer the gentler account. Leave the evidence with her.', result='Elna names his kindness and the people he shut outside. She chooses to give the assembly what she knows.' if truth else 'Elna receives the bell and the written record. She declines a public account; the act itself stays documented.')
        action['sets_flags']['witness_consent_elna'] = 'voluntary' if truth else 'refused'
elna['actions'].append(choice('Tell her everything privately. Keep her grief out of the square.', 'side_widows_bell', 'widow_choice', {'widow_truth': 'private', 'witness_consent_elna': 'refused'}, 'Elna accepts Harl\'s record for the family. His act remains evidence; her grief is not pledged to the assembly.', conditions={'objectives_done': [done('side_widows_bell', 'find_bell')]}))

tor = scene(d, 'blacksmith_tor', 'Keep the scrap. I can spare a hinge more easily than another cart stuck outside.', [
    'Tor: The forge still runs. If the road goes, every household will want a latch before they want a sword.',
    'Kael: There are letters ground off this iron.',
    'Tor: Refugee marks. I recognized them years ago. Told myself metal did not care who used it next.',
    'Tor: Some of it is holding doors shut against the rain. You want it back, tell me what we put in its place.'], [
    variant(80, {'iron_fate': 'memorial'}, 'The new nails carry the names where a hammer will not strike them away.', ['Tor: I am replacing one working piece at a time. Elna still has a door while I make the marker.', 'Kael: What did it cost?', 'Tor: Two contracts. A late night. Less than grinding those letters off cost somebody else.']),
    variant(80, {'iron_fate': 'tools'}, 'The refugee marks face outward now. Nobody buys this stock without being told.', ['Tor: The tools stay useful. A share of each sale goes to replacement iron and the road record.', 'Kael: You will say that publicly?', 'Tor: I already wrote it above the price.']),
    variant(80, {'iron_fate': 'surrendered'}, 'The marked stock is on the table, with the forge accounts beside it.', ['Tor: Anwen will keep it until the families decide. I work from new scrap now.', 'Kael: Is the forge closing?', 'Tor: Not if you stop talking and help carry the clean iron.'])])
for action in tor['actions']:
    if action.get('type') == 'start_quest': action['label'] = 'Show me the marks that survived grinding.'
    if action.get('objective') == 'tor_choice':
        old = action['sets_flags']['iron_fate']
        if old == 'memorial':
            action.update(label='Replace the useful iron gradually. Make named memorial work.', result='Tor begins replacement before dismantling working objects. Memorial nails carry the recovered names; his forge remains open.')
        else:
            action.update(label='Keep the tools in use. Disclose their source and fund replacement.', result='Tor leaves the marks visible and posts the source above his prices. The useful stock stays in working hands.')
            action['sets_flags']['iron_fate'] = 'tools'
        action['sets_flags']['witness_consent_tor'] = 'voluntary'
tor['actions'].append(choice('Surrender the marked stock. Let the families decide its use.', 'side_iron_remembers', 'tor_choice', {'iron_fate': 'surrendered', 'witness_consent_tor': 'voluntary'}, 'Tor hands over the stock and his account. He keeps the forge running on ordinary scrap while the disputed iron stays intact.', conditions={'objectives_done': [done('side_iron_remembers', 'recover_iron')]}))

toma = scene(d, 'farmer_toma', 'She is asleep. Speak low. Mira finally got the fever down.', [
    'Toma: My daughter was outside when the bandits came. The thing at the fold put itself between her and a blade.',
    'Kael: And the missing sheep?',
    'Toma: I fed it. Then I hid it. It started taking from the next field and I kept telling myself gratitude was different from a danger.',
    'Toma: Read the boot marks with the tracks. I want the whole cause found, even the part that is mine.'], [
    variant(80, {'guardian_plan': 'relocated'}, 'The outer boundary is marked. My daughter knows the posts mean stop.', ['Toma: The creature follows the old protection path beyond the fields. I warned the neighbors this time.', 'Kael: A boundary only works if everyone knows where it is.']),
    variant(80, {'guardian_plan': 'supervised'}, 'There is a watch at the fold and a warning on every gate.', ['Toma: I do not call it harmless. I call the neighbors before I feed it.', 'Kael: They get to change their minds.', 'Toma: Yes. Even when I wish they would not.']),
    variant(80, {'guardian_plan': 'killed'}, 'The fold is quiet. She keeps asking why the thing that protected her had to die.', ['Toma: I told her about the sheep. And that I hid it until there were no easy choices left.', 'Kael: Keep its protection in the account too.']),
    variant(75, {'black_dog_fate': 'hidden'}, 'The neighbors stopped asking. That is not the same as the danger ending.', ['Toma: I heard it at the next field last night. I will not tell you I was surprised.'])])
for action in toma['actions']:
    if action.get('type') == 'start_quest': action['label'] = 'I will compare the tracks and the bandits\' camp.'
    if action.get('objective') == 'dog_choice':
        if action['sets_flags']['black_dog_fate'] == 'spared':
            action.update(label='Move its protection path beyond the farms. Warn the neighbors.', result='Toma marks the outer boundary and moves the feeding place. The guardian survives beyond the fields; its danger is acknowledged.')
            action['sets_flags']['guardian_plan'] = 'relocated'
        else:
            action.update(label='Keep it at the fold under a disclosed village watch.', result='Toma tells the neighbors and organizes a watch. Protection remains, but the village can withdraw its agreement.')
            action['sets_flags'].update(black_dog_fate='spared', guardian_plan='supervised')
toma['actions'].append(choice('End the dangerous guardian. Record why it protected her.', 'side_black_dog', 'dog_choice', {'black_dog_fate': 'killed', 'guardian_plan': 'killed'}, 'The protection fragment is put to rest. Toma names the people it saved and the livestock his secrecy cost.', conditions={'objectives_done': [done('side_black_dog', 'find_dog')]}))

scene(d, 'returned_soldier', 'Hold the gate. Hold the gate. The lantern is on the wrong side.', [
    'Kael: You are repeating one night. Can you tell me your name?',
    'The Returned Soldier: Len. Mother left the lantern. Hold the gate.',
    'Kael: A fragment caught in an empty grave. Not a man who knows what happened afterward.',
    'The Returned Soldier: Len. The lantern is on the wrong side.'], [])
for action in d['returned_soldier']['actions']:
    named = action['sets_flags']['returned_soldier_fate'] == 'named'
    action.update(label='Record Len\'s name. Let the repeated watch end.' if named else 'Settle the fragment privately. Preserve the name in the book.', result='The lantern memory goes still. Len\'s name is entered beside the gate account; the fragment offers no new oath.' if named else 'The grave settles. Len\'s name remains in the recovered record without a public spectacle.')
    action['sets_flags']['returned_soldier_is_fragment'] = True

scene(c, 'miller_record', 'The measure is hollow under its mark. The short weight has been feeding the same households for years.', [
    'Kael: The ledger counts ash as fertilizer. The wagon totals match the refugee register.',
    'Mira: Closing the mill stops the tainted channels. It also stops the flour coming through them.',
    'Kael: The record leaves with us whatever we do to the machinery.',
    'Mira: Good. Now decide how we feed the people who did not choose what was ground here.'], [])
mill = c['miller_record']['actions']
mill[0].update(label='Close the tainted channels. Preserve the ledger and ration reserves.', result='The ledger is kept. The mill closes while relief grain is divided; workers lose shifts and the village must carry sacks from the reserve.')
mill[0]['sets_flags'].update(mill_operation='closed', mill_records_preserved=True)
mill[1].update(label='Keep supervised milling. Replace the contaminated working copy.', result='The ruined working sheet is burned after a signed copy is kept. Supervised milling supplies flour while separate clean channels are prepared.')
mill[1]['sets_flags'].update(mill_operation='supervised', mill_records_preserved=True)
mill[2].update(label='Post the accounts. Begin clean repairs and pay for restitution.', result='The accounts are copied publicly. Workers begin replacing the channels; the first clean flour goes to affected households.')
mill[2]['sets_flags'].update(mill_operation='restitution', mill_records_preserved=True)

scene(c, 'captain_senn', 'Put the sword down far enough that my men can see what surrender looks like.', [
    'Senn: I was on that road in the war. Young enough to call an order the whole explanation.',
    'Senn: Halvern refused to close the retreat. They hanged him. I closed it after him.',
    'Kael: Now you take grain from travelers and call it repayment.',
    'Senn: I said their houses owed ours. It became an excuse before I stopped needing it.',
    'Kael: You can give testimony. You still answer for the people hurt this week.'], [
    variant(60, {'senn_fate': 'testimony'}, 'My men have the custody terms. No levy can take their children for what I ordered.', ['Senn: I will speak. I am not asking the account to wipe the road clean.', 'Kael: Then sign the part you know. Leave the rest for the people who lived it.']),
    variant(60, {'senn_fate': 'exile'}, 'The camp is packing. The signed account stays with you.', ['Senn: My men leave their blades for the grain they took.', 'Kael: Leaving does not make the missing travelers someone else\'s problem.'])])
for action in c['captain_senn']['actions']:
    if action.get('objective') == 'senn_choice':
        fate = action['sets_flags']['senn_fate']
        if fate == 'testimony': action.update(label='Accept surrender under custody. Ask for freely given testimony.', result='Senn lays down his sword and signs his own account. Custody remains; his oath to speak is voluntary.'); action['sets_flags']['witness_consent_senn'] = 'voluntary'
        elif fate == 'exile': action.update(label='Take the written account. Disarm the camp and permit exile.', result='Senn leaves the confession and stolen supplies. He goes without offering a living oath.'); action['sets_flags']['witness_consent_senn'] = 'refused'
        else: action.update(label='Execute Senn for the road killings. Keep the documented account.', result='Senn dies. The camp\'s signed account survives; no dead man is counted as a consenting living witness.'); action['sets_flags']['witness_consent_senn'] = 'refused'
        action['sets_flags']['senn_account_recovered'] = True
    if action.get('objective') == 'debt_choice':
        public = action['sets_flags']['bannerless_fate'] == 'testimony'
        action['result'] = 'The deserters choose to sign what they saw. Their refusal corroborates the command; it does not absolve what they did before it.' if public else 'The refusal is copied without homes or relatives. Senn\'s crimes remain public while his former soldiers receive a protected route.'

scene(c, 'halvern', 'Do not close it. There are still people on the road.', [
    'Halvern: Sanctuary under the Vargan seal. Those were the words. They came because of the words.',
    'Kael: What happened after you refused?',
    'Halvern: Rope. The yard. Dawn. Do not close it.',
    'Kael: You cannot tell me about Edric. Your memory ends here.',
    'Kael: I was ordered to retreat from another road. There were people we had promised to escort. I went.',
    'Kael: I wrote that we could not hold. I left out that I never went back.',
    'Halvern: There are still people on the road.'], [])
for action in c['halvern']['actions']:
    fate = action['sets_flags']['halvern_fate']
    action['sets_flags'].update(kael_confessed=True, command_proof_recovered=True, halvern_is_fragment=True)
    if fate == 'witness': action.update(label='Preserve the refusal as testimony. Do not demand another oath.', result='Kael copies the sanctuary order and refusal. The bounded memory stays with the blade; it cannot consent for a living person.')
    elif fate == 'released': action.update(label='Record the refusal, then release the exhausted memory.', result='The order and refusal are copied before the fragment settles. Kael keeps his own confession in the same account.')
    else: action.update(label='Keep the copied order. End the remaining grave binding.', result='The irreplaceable shape is destroyed after its command is recorded. The copied proof remains; its surrounding memories are lost.')

scene(c, 'edric_campaign', 'The grain you saw outside is real. So is the road that killed the people sent to clear it.', [
    'Edric: I found the command ledger six years ago. I sealed it. I was afraid of what the houses here would become without Vargan protection.',
    'Kael: You inherited the crime. Keeping its proof hidden was your choice.',
    'Edric: Yes. The renewal is my choice too. I need households to witness the seal before the grain moves.',
    'Kael: People who must sign to feed their children cannot give you a free oath.',
    'Edric: Then give me another way to get those carts through. Do not give me a principle and leave before winter.'], [
    variant(50, {'edric_stance': 'cooperate'}, 'I have withdrawn the household signatures. My officers have the same order.', ['Edric: I will testify without my seal. I will supply the road under the assembly\'s account.', 'Kael: Your title?', 'Edric: Not mine to shelter behind after this.']),
    variant(50, {'edric_stance': 'compelled'}, 'I will say what you make me say. Do not dress it as consent.', ['Kael: Your ledger is evidence. Your threatened words are not a new covenant.', 'Edric: At least we agree on the shape of what you are doing.'])])
for action in c['edric_campaign']['actions']:
    stance = action['sets_flags']['edric_stance']
    action['sets_flags'].update(renewal_announced=True, command_proof_recovered=True)
    action['sets_flags']['witness_consent_edric'] = {'cooperate': 'voluntary', 'exposed': 'refused', 'compelled': 'compelled'}[stance]
    if stance == 'cooperate': action.update(label='Protect his hearing, not his title. Ask him to stop the renewal.', result='Edric voluntarily agrees to testify and release the grain without household signatures. His title and accounts pass to the public hearing.')
    elif stance == 'exposed': action.update(label='Make the ledger public. Remove his power to require signatures.', result='The ledger is exposed and the seal challenged. Edric refuses a personal oath; the proof is sufficient without pretending he agrees.')
    else: action.update(label='Compel his admission. Use the ledger as evidence, not his oath.', result='Edric admits his concealment under pressure. His words establish facts; the new covenant must use someone else\'s freely given responsibility.')

scene(c, 'assembly_choice', 'Edric\'s grain list lies beside the new seal. Some households have already signed because their sacks are empty.', [
    'Anwen: The wax will not hold. They agreed to eat, Edric. They did not agree to carry the road.',
    'Kael: I left civilians on a road after promising escort. I called it a retreat in my report. That part of my report was a lie.',
    'Rook: Then do not ask us to sign yours because you finally stayed.',
    'Kael: I will not. The copies establish what happened. Each of you decides whether to offer more.',
    'Anwen: Break the grain condition before you touch the seal. Otherwise the rite only learns a new way to threaten us.'], [
    variant(40, {'edric_stance': 'cooperate'}, 'Edric removes his seal from the grain list in front of the waiting households.', ['Edric: Every household receives its allotment. No signature. My account comes afterward.', 'Kael: I left people behind under a retreat order. I stayed away and called it duty. That is my account before I ask for yours.', 'Rook: Then give people time to decide. A hand raised in relief is not an oath.'])])
for action in c['assembly_choice']['actions']:
    if action.get('objective') == 'confession_choice':
        method = action['sets_flags']['confession_method']
        action['sets_flags'].update(renewal_stopped=True, kael_confessed=True, command_proof_recovered=True, assembly_relief_ready=True)
        if method == 'witnesses': action.update(label='Release the grain. Invite only those who choose to speak.', result='The ration condition is struck out. Willing witnesses speak; anyone who refuses can receive food and leave. Kael keeps the remaining record.')
        elif method == 'kael': action.update(label='Break the ration condition. Carry the account yourself.', result='Kael removes the renewal seal and reads the copied account. No household is pledged by being present. He accepts the work of preserving what he read.')
        else:
            action.update(label='Break the condition and make Edric answer from the ledger.', result='The coercive renewal is stopped. Edric\'s compelled admission is entered as evidence; it is not counted as consent to the replacement covenant.')
            action['sets_flags']['witness_consent_edric'] = 'compelled'

scene(c, 'names_decision', 'Rook puts a clean sheet over the family addresses before he hands you the register.', [
    'Rook: The people who died can be named. Where their grandchildren sleep is not the same fact.',
    'Anwen: Bram found the tokens in the repaired road. Sella brought one for a burial reading. Oren restored the first name beneath his paint.',
    'Kael: The name loosened what the hidden road had kept disordered.',
    'Anwen: And my thread failed to contain it. Vargan\'s men came afterward for the tokens.',
    'Rook: Now Edric wants those households at a renewal. No signature, no grain. Your copies will reach them before his guards do.'], [])
for action in c['names_decision']['actions']:
    published = action['sets_flags']['names_policy'] == 'published'
    action['sets_flags'].update(renewal_announced=True, crisis_cause_known=True, protected_family_addresses=True)
    action.update(label='Publish the recovered names and order. Remove family addresses.' if published else 'Keep protected copies until the assembly. Tell each affected household.', result='The dead are named publicly and Edric\'s order is challenged. Family addresses stay off the board; fear and solidarity both follow.' if published else 'Anwen and Rook keep separate copies. Affected households are warned privately before the assembly; the delay leaves the public order unchallenged for now.')

scene(c, 'crow_shrine_choice', 'The red thread pulls tight toward the sealed road. Anwen cuts her own prayer cord before touching it.', [
    'Anwen: I used to say the shrine kept the dead quiet. It kept their names apart.',
    'Kael: What does each way cost?',
    'Anwen: Clean the rite and the danger moves out toward the wood. Open it and memory enters this place. Hold it shut and the next repair may tear it again.',
    'Anwen: None of those asks the dead what they wanted. A living witness can freely take the work of keeping their account. Not the right to make them disappear.'], [])
for action in c['crow_shrine_choice']['actions']:
    state = action['sets_flags']['crow_shrine_state']
    action['sets_flags']['covenant_rules_known'] = True
    action['label'] = {'cleansed': 'Clean the rite. Accept the danger shifting to the wood.', 'disturbed': 'Open the memory. Keep the gathered names intact.', 'bound': 'Hold the seal for now. Mark its limits in the record.'}[state]
    action['result'] = {'cleansed': 'The chapel quiets. Anwen records that the debt was redirected, not erased, and goes to name the graves.', 'disturbed': 'The erased names surface at the shrine. The village hears the bell; the recovered fragments are kept intact.', 'bound': 'The seal holds temporarily. Kael marks its weakness instead of calling the silence a cure.'}[state]

scene(c, 'bog_core_choice', 'The root knot tightens around a small painted crow. One frightened moment keeps moving through it.', [
    'Mira: Oren said the name. Something opened. This is not him returned to answer us.',
    'Kael: If we break it?',
    'Mira: This vessel stops. Its memory disperses. If we keep it, we must stop treating every reaction as an invitation.',
    'Kael: Or return the fragment where his name can hold it.',
    'Mira: Yes. I can refine the oil whichever way you choose. I will not price a formula against a child\'s memory.'], [
    variant(20, {'bog_core_exposed': True}, 'The Moon Oil reveals a groove beneath the new paint. Oren had restored the first name on the old token.', ['Mira: The creatures gathered what the road could no longer hide. The wire came later.', 'Kael: Vargan tried to contain the evidence.', 'Mira: Keep that fact. This fragment cannot tell us everything that happened.'])])
for action in c['bog_core_choice']['actions']:
    fate = action['sets_flags']['bog_core_fate']
    action['sets_flags'].update(crisis_cause_known=True, mira_truth_known=True)
    action['result'] = {'destroyed': 'The vessel collapses; its memory disperses into the wet ground. Mira keeps ordinary medicine available and prepares the refined oil.', 'preserved': 'Mira wraps the fragment and limits her study to what is already exposed. The future treatment must respect family consent.', 'returned': 'The fragment is settled beneath Oren\'s named marker. Its dangerous shape ends without opening its intimate memory to the village.'}[fate]

scene(c, 'white_hart', 'You have kept the account where a living hand can reach it. That is something the old oath would not allow.', [
    'Kael: The grain condition is broken. No one standing here has to promise you anything to eat.',
    'The White Hart: I remember the gate shut. I remember the road hidden. I remember the soldiers entering. I will not tell you those were one man\'s act.',
    'Kael: The copies survive. I will freely keep what we have recovered. I cannot swear for the people who refused.',
    'The White Hart: One willing keeper of an account is enough to begin. Others may share that work. None may be given it by force.',
    'The White Hart: Make the account public and I will leave its judgment with you. Release me quietly and preserve the record without opening every private memory.',
    'The White Hart: Or carry the unresolved binding yourself. Or destroy me and lose what no copy holds.',
    'Kael: Releasing you does not erase the house\'s crime. Protecting a family does not protect Edric from the record.',
    'The White Hart: Then choose whose work begins when mine ends.'], [])
c['white_hart']['actions'] = [
    {'label': 'Witness — make the account public; stay to preserve it.', 'type': 'ending', 'ending': 'expose'},
    {'label': 'Mercy — release the Hart; safeguard names and private memories.', 'type': 'ending', 'ending': 'free'},
    {'label': 'Duty — freely carry the unresolved binding myself.', 'type': 'ending', 'ending': 'bind'},
    {'label': 'Ash — destroy the Hart; keep the human record and face the loss.', 'type': 'ending', 'ending': 'kill'}]
d['white_hart'] = deepcopy(c['white_hart'])

scene(c, 'witness_-7', 'I grew the medicine in the ash bed. Families were not told.', ['Mira: Some choose it now. Others choose the clean roots. I still treat them.', 'Mira: The cure was real. So was the choice I kept from them.'], [variant(50, {'mira_truth': 'destroyed'}, 'The ash bed is closed. I will explain why the replacement takes longer.', ['Mira: There will be shortages. I will not hide them behind a clean label.'])])
scene(c, 'witness_-3', 'I can tell you where the road ran. I have removed the family homes from the copy.', ['Rook: My grandmother kept these names. She did not leave me permission to hand you every private part of her life.', 'Rook: The road is evidence. The addresses are not.'], [variant(50, {'witness_consent_rook': 'refused'}, 'You have the route. You do not have my promise to stand in a rite.', ['Rook: A record is not a person agreeing. Keep that straight.'])])
scene(c, 'witness_3', 'I resealed the book after the novice died. Every year afterward I called it care.', ['Anwen: I was afraid. That explains what I did. It does not give the unnamed people back their years.', 'Anwen: My confession is my own. No household has to follow it to receive grain.'])
scene(c, 'witness_7', 'Bram Kett. Sella Vey. Oren Vey. The older name beneath the painted crow.', ['Kael: These pages establish what we recovered. They do not promise for the people who could not come.', 'Kael: Leave room for what the Hart knows that our copies do not.'])
scene(c, 'retain_evidence', 'A thumb-sized crow. Fresh paint above a name cut into older wood.', ['Kael: Oren was making something someone had erased readable again.', 'Kael: Keeping this close gives me time. It also leaves everyone else waiting for an account.'])
scene(c, 'side_contracts', 'Elna has pinned a bell cord here. Tor has weighted a note with a bent hinge. Mira\'s paper smells of roots.', ['Some ask for payment. Some ask that you knock quietly. Rook\'s note has a road drawn on the back.', 'Kael: People to return to. Not just work to finish.'], [])
for action in c['side_contracts']['actions']:
    action['label'] = {'side_widows_bell': 'Visit Elna about Harl\'s bell.', 'side_iron_remembers': 'Ask Tor about the marks in his iron.', 'side_bitter_roots': 'Help Mira find another fever treatment.', 'side_black_dog': 'Hear Toma\'s account of the sheepfold.', 'side_empty_grave': 'Follow the watch that left an empty grave.', 'side_childs_charm': 'Return Oren\'s thread to a named place.', 'side_soldiers_debt': 'Carry the Bannerless soldiers\' refusal.', 'side_millers_measure': 'Recover the true weight of the ash.', 'side_rooks_map': 'Walk Rook\'s road against the waystone.', 'side_three_candles': 'Light a candle for each missing traveler.'}[action['quest']]

scene(c, 'vargan_gate_guard', 'Keep the lane clear. That cart is carrying grain, not reinforcements.', ['Kael: I carry an account from Greyfen\'s road.', 'Guard: The steward wants every token brought inside. People argue less over a missing thing when no one can show it.', 'Kael: Then you had better let me show it.'], [variant(20, {'castle_guard_suspicious': True}, 'The steward says a seal was broken. I can see why he is frightened.', ['Guard: You may still leave by the gate. The road must carry people as well as orders.'])])
scene(c, 'vargan_steward', 'The empty sacks go left. The petitions go right. Do not mix them.', ['Kael: Why are household signatures beside grain allotments?', 'Merrow: A supported household witnesses the renewal. Those are the terms.', 'Kael: Terms offered to someone hungry do not make a free promise.'], [])
scene(c, 'vargan_servant', 'I set an extra place when the grain drivers are late. It does not get them here, but it keeps someone expecting them.', ['The archive lamps answer names cut from the old books. Start with the marks along the shelf. Not every answer has a voice.'], [])
scene(c, 'vargan_patrol', 'We were sent for the painted tokens after the creatures gathered. Two men did not come back.', ['Kael: Did your orders include scratching out their names?', 'Guard: Contain the breach. Bring back every object. The paper did not say what to do when a child\'s name made the wire shake.'], [])
scene(c, 'vargan_record_keeper', 'I have laid the uncut page under the lamp. You may read it. I have waited too long to say that.', ['Vale: Sanctuary was promised under the Vargan seal. The closure order followed on the same day.', 'Kael: You kept both?', 'Vale: I kept them and let the steward keep people from reading them. I will sign that fact.'], [])
scene(c, 'edric_castle', 'Sit if your leg is hurting. Then tell me exactly what you found.', ['Kael: Your soldiers reclaimed the tokens after the road repairs.', 'Edric: I ordered containment. The repairs had exposed a cache the shrine could no longer quiet.', 'Kael: You also kept the ledger closed for six years.', 'Edric: Yes. Before you ask the next question, know that I have no smaller word for that.'], [])
scene(c, 'vargan_ledger_choice', 'Sanctuary promised. Road closed. Refugee wagons transferred to shrine custody. Three columns written by three different hands.', ['Kael: The command survived without the names. The register has the names without the command.', 'Kael: Together they establish who did what. Copy the page before any choice about its seal.'], [])
for action in c['vargan_ledger_choice']['actions']:
    action.setdefault('sets_flags', {})['command_proof_recovered'] = True
    action['sets_flags']['command_ledger_copied'] = True
    if action['label'].startswith('Take'): action['result'] = 'Kael copies the command, then takes the original in sight of the keeper. The broken seal raises suspicion; the facts survive.'
    elif action['label'].startswith('Hide'): action['result'] = 'A copy stays with the keeper. Kael conceals the original to protect the route out; the hidden removal damages trust if discovered.'
    else: action.update(label='Keep a signed copy. Leave the original where it can be read.', result='Vale signs the copy. The original stays open under the lamp, and the command proof leaves with Kael.')

# Legacy resolve-all dialogue is retained as an ordinary recollection, with no shortcut actions.
scene(c, 'village_stories', 'A bell on a windowsill. New nails beside an old hinge. Roots laid out beneath labeled jars.', ['Kael: What matters is whether I returned after asking them to change.'], [])
c['village_stories']['actions'] = []

scene(c, 'greyfen_cart_work', 'The wheel has sunk to its hub. Rook braces the cart while the driver tries not to fall against it.', ['Rook: If you are hunting something expensive, consider this wheel. It has eaten my entire morning.', 'Kael: Move your hand from the spoke. I will take the weight.', 'Rook: Then Anwen gets the driver, and the sacks get through the gate. In that order.'], [variant(30, {'cart_helped': True}, 'The cart stands on dry boards. The driver has Anwen\'s cup between both hands.', ['Rook: Grain inside. Person inside. A profitable morning by standards I have apparently lowered.'], [])])
c['greyfen_cart_work']['name'] = 'Rook'
c['greyfen_cart_work']['actions'] = [choice('Brace the wheel and help bring the driver inside.', flags={'cart_helped': True}, result='Kael lifts while Rook lays boards. The grain and its shaken driver reach Greyfen together.', conditions={'flag_unset': 'cart_helped'})]
scene(c, 'greyfen_road_work', 'Rain has opened the repaired strip where Bram found the old tokens.', ['Tor: Put the clean boards over the rut. Leave the marked pieces where we can read them.', 'Kael: Repair the route without burying what it exposed.'], [variant(30, {'road_repaired': True}, 'Clean boards span the rut. The marked fragments lie beside the warning post.', ['Kael: People can pass here. The evidence has not gone back under their wheels.'], [])])
c['greyfen_road_work']['actions'] = [choice('Lay clean boards and preserve the exposed fragments.', flags={'road_repaired': True}, result='The crossing is repaired. Refugee marks remain visible beside it instead of disappearing beneath new fill.', conditions={'flag_unset': 'road_repaired'})]
scene(c, 'edric_proclamation', 'By order of Lord Edric Vargan: grain protection is to be restored under a renewed road covenant.', ['Each supported household must attend and witness the seal. Allotments will be entered beside its assent.', 'Kael: An order can move grain. It cannot make a hungry person\'s oath free.'], [variant(40, {'renewal_stopped': True}, 'The household assent column has been struck from the order.', ['Grain allotments remain. The account of the road is kept separately.'], [])])
c['edric_proclamation']['actions'] = [choice('Keep the renewal order with the road evidence.', flags={'renewal_announced': True}, result='The current order joins the older command. Protection and assent have been deliberately made the same transaction.', conditions={'flag_unset': 'renewal_announced'})]
scene(c, 'greyfen_relief_board', 'Anwen has left spaces for grain, medicine, clean iron, and a safe bed.', ['Anwen: You may put your hand to one of those without agreeing to stand before the Hart.', 'Kael: Then keep the names of helpers away from the renewal seal.'], [variant(30, {'assembly_relief_ready': True}, 'Grain sacks and clean cloth sit beside the assembly. The way out remains clear.', ['Kael: Practical help before an oath. Nobody has to become evidence to receive it.'], [])])
c['greyfen_relief_board']['actions'] = [choice('Arrange food, treatment, and a clear exit for the assembly.', flags={'assembly_relief_ready': True}, result='The relief list is kept separate from testimony. Food and a safe exit are offered whether a household speaks or refuses.', conditions={'flag_unset': 'assembly_relief_ready'})]
scene(c, 'mill_distribution', 'Clean reserve sacks stand apart from the mill\'s working channel.', ['Mira: A short ration is a cost. So is using tainted machinery. The ledger does not make either disappear.', 'Kael: Keep the record whatever method gets the flour through.'], [])
c['mill_distribution']['actions'] = []
c['mill_distribution']['variants'] = [
    variant(30, {'mill_operation':'closed'}, 'The tainted channel is closed. Reserve sacks are divided by household need.', ['Mira: Clean repair takes time. For now, these sacks are what keeps the closure from becoming another barred gate.'], []),
    variant(30, {'mill_operation':'supervised'}, 'The limited run is watched. Contaminated stock is stacked separately.', ['Mira: It gets flour through today. It does not settle what went into the channels or the work of replacing them.'], []),
    variant(30, {'mill_operation':'restitution'}, 'Clean repairs have begun. The first replacement sacks go to affected households.', ['Kael: The accounts stay public. Repair is work that people can return to see.'], [])]
scene(c, 'renewal_record', 'The old covenant hid a road. The proposed renewal would have hidden an account.', ['The victims trusted a promise of sanctuary. The witnesses to concealment were frightened into agreement.', 'Kael: Copies prove the crime. A new promise must belong to the person who makes it. No ration list can lend somebody else\'s consent.'], [])
scene(c, 'report_decision', 'Anwen puts three empty cups beside the coat Oren left. Rook waits by the door.', [
    'Kael: The creatures gathered their belongings. Someone alive bound the token afterward and tried to remove it.',
    'Anwen: I recognize the old carving. You can give it to me, show the village, or keep it while we make copies.',
    'Rook: If you show it, show the people behind it a way to stay safe as well.',
    'Kael: I will stay. The payment ends the hunt. It does not settle what I now know.'], [])
c['report_decision']['name'] = 'Sister Anwen'
c['report_decision']['actions'] = [
    choice('Give Anwen the token privately. Stay to protect those who speak.', 'main_road_of_crows','return_village', {'evidence_report':'private','kael_pledge':'protect','cemetery_bell_rung':True,'legacy_report_choice_required':False}, 'Anwen recognizes the older name and agrees to open the account. Kael stays to help protect its living witnesses.', {'anwen_trust':1}),
    choice('Make the evidence public. Stay to keep the witnesses safe.', 'main_road_of_crows','return_village', {'evidence_report':'public','kael_pledge':'account','cemetery_bell_rung':True,'legacy_report_choice_required':False}, 'The token and wire are pinned beneath the contract. Some doors close; somebody brings dry cloth to cover the token. Kael remains responsible for the people newly visible.', {'greyfen_fear':1,'anwen_trust':-1}),
    choice('Keep the token. Make protected copies and stay with the investigation.', 'main_road_of_crows','return_village', {'evidence_report':'retained','kael_pledge':'stay','cemetery_bell_rung':True,'legacy_report_choice_required':False}, 'Kael keeps the original and commits to copies. Anwen distrusts the delay, but he has promised to remain with the people who must carry the account.', {'anwen_trust':-1})]

# The garden is evidence, never an automatic treatment decision.
q['side_bitter_roots']['objectives'].insert(1, {'id':'study_roots','text':'Examine the ash bed separately from the treatment decision.','optional':True})

# Keep migration IDs and interactable bindings; replace the questions and destination language.
objective_text = {
 'main_road_of_crows': {'speak_anwen':'Hear Anwen\'s account of the missing travelers.', 'evidence_ready':'Find why the missing travelers carried old tokens.', 'fight_ghoulkin':'Recover the travelers\' belongings from the clearing.', 'return_village':'Return with the account. Decide who receives the evidence.'},
 'main_bell_beneath_greyfen': {'grave_truth':'Learn what the disturbed graves are carrying.', 'open_chapel':'Open the sealed chapel with Anwen.', 'crow_shrine_choice':'Choose what the shrine will contain, release, or redirect.'},
 'main_teeth_in_rain': {'speak_mira':'Ask Mira how a restored name changes a memory.', 'name_the_dead':'Speak Oren\'s name at the stones and watch the response.', 'bog_core_choice':'Decide how to settle the fragment the Wretch carried.'},
 'main_names_they_burned': {'reconstruct_register':'Reconstruct the sanctuary promise and the recovered names.', 'names_choice':'Share the account now or prepare protected copies for the assembly.'},
 'main_ash_at_the_mill': {'reach_mill':'Reach the mill that supplies Greyfen.', 'inspect_millstones':'Compare the ash measure with the missing wagons.', 'mill_encounter':'Protect the working route from the ash-bound threat.', 'mill_choice':'Keep the evidence and choose how Greyfen receives flour.'},
 'main_soldier_without_banner': {'senn_confrontation':'Obtain Senn\'s surrender or overcome his guard.', 'senn_choice':'Resolve Senn\'s accountability and preserve his account.'},
 'main_blood_under_stone': {'recover_ledger':'Read the command beside the refugee register.', 'ledger_choice':'Keep a credible copy of the command and decide how to leave with it.', 'last_witness_hook':'Confront Edric\'s renewal and follow the record to Halvern.'},
 'main_last_witness': {'break_halvern_guard':'Hear the refusal caught inside Halvern\'s grave oath.', 'halvern_choice':'Keep the command proof and resolve the bounded memory.'},
 'main_crowns_without_mercy': {'gather_witnesses':'Prepare willing speakers and records from those absent.', 'greyfen_assembly':'Open the assembly with aid independent of testimony.', 'confession_choice':'Stop the coerced renewal and decide how the account is heard.'},
 'main_hart_remembers': {'hear_testimony':'Hear the Hart. Understand the cost of each freely chosen resolution.', 'final_choice':'Enact Witness, Mercy, Duty, or Ash.'},
 'side_widows_bell': {'widow_choice':'Give Elna the account and respect her choice of participation.'},
 'side_iron_remembers': {'tor_choice':'Choose disclosure, replacement, or surrender of the marked stock.'},
 'side_bitter_roots': {'collect_roots':'Gather the marked roots and examine the fever treatment.', 'mira_choice':'Agree a treatment plan with disclosure and a practical alternative.'},
 'side_black_dog': {'find_dog':'Compare guardian tracks with the people who attacked the fold.', 'dog_choice':'Relocate, supervise, or end the dangerous protection fragment.'},
 'side_empty_grave': {'walker_choice':'Settle Len\'s repeated watch and preserve its name.'},
 'side_rooks_map': {'map_choice':'Keep the route useful without deciding Rook\'s consent for him.'},
 'side_soldiers_debt': {'debt_choice':'Carry the soldiers\' refusal with public or protected identities.'},
 'side_millers_measure': {'ash_choice':'Give the true measure to people who can act on it.'}}
deep = {'side_widows_bell','side_iron_remembers','side_bitter_roots','side_black_dog','side_rooks_map','side_soldiers_debt'}
for quest_id, quest in q.items():
    quest['story_depth'] = 'main' if quest.get('type') == 'main' else ('deep' if quest_id in deep else 'interlude')
    for objective in quest.get('objectives', []):
        objective['text'] = objective_text.get(quest_id, {}).get(objective['id'], objective['text'])
        if 'tracker_text' in objective:
            objective['tracker_text'] = {'road_evidence':'Investigate the travelers\' last journey', 'grave_evidence':'Read the disturbed graves', 'castle_evidence':'Follow the command through Vargan\'s records'}.get(objective.get('group'), objective['text'])

# Every new irreversible choice carries a readable intended result before commitment.
for table in (d, c):
    for row in table.values():
        row.setdefault('content_version', 2)
        for action in row.get('actions', []):
            if action.get('type') == 'story_choice':
                action['preview'] = action.get('result', '')
                action['cost'] = {
                    'return_village':'Public disclosure can expose witnesses; private or retained evidence delays the wider account.',
                    'mill_choice':'Closure uses reserves; supervision retains contamination risk; restitution takes clean materials and labor.',
                    'senn_choice':'Custody needs protection; exile removes a living witness; execution destroys future testimony.',
                    'halvern_choice':'Copies preserve the refusal, not every memory the fragment carries.',
                    'names_choice':'Delay leaves the renewal order unchallenged; publicity can endanger people who carry the account.',
                    'last_witness_hook':'Protection cannot shelter Edric\'s title; compelled words establish facts without supplying consent.',
                    'confession_choice':'The renewal must end without withholding food from anyone who refuses to speak.',
                    'mira_choice':'Alternative treatment is slower. Continued ash use needs families who can freely refuse it.',
                    'tor_choice':'Restitution takes stock and labor; useful objects still need replacement.',
                    'map_choice':'A public route can endanger marked families; a destroyed map cannot help the next traveler.',
                    'widow_choice':'The act remains recorded; Elna decides whether her grief becomes public.',
                    'dog_choice':'Protection carries danger; ending the fragment loses the guard it offered.'
                }.get(action.get('objective',''), 'This records an explicit promise or practical action. A record cannot supply someone else\'s consent.')
            elif action.get('type') == 'ending':
                action['preview'] = {'expose':'Release the Hart through public acknowledgment and Kael\'s willing work to preserve the record.', 'free':'Release the Hart while protecting private memories; institutional crimes remain on record.', 'bind':'Kael willingly carries the continuing binding. No other person is pledged.', 'kill':'Destroy the complete witness by combat; the copied human record survives.'}[action['ending']]
                action['cost'] = {'expose':'Lost privilege, trade pressure, and the ongoing labor of restitution. Fewer allies mean more work for Kael.', 'free':'A protected circle must preserve the truth; partial public acknowledgment leaves unresolved grievances.', 'bind':'Kael loses freedom and rest. The village gains time while the injustice remains unfinished.', 'kill':'Irreplaceable memories are lost. Dispersal harms the land and future harvests.'}[action['ending']]

write('dialogue.json', d)
write('campaign_dialogue.json', c)
write('quests.json', q)

chapters = [
 ('main_road_of_crows','Road of Crows','Why were the travelers carrying erased names?','Bram, Sella, and Oren carried recovered tokens from recent road repairs. Their belongings drew Ghoulkin; a living hand tried to erase the aftermath.','Bring an honest account back to people who loved them. Decide who can safeguard the evidence.'),
 ('main_bell_beneath_greyfen','Bell Beneath Greyfen','What did the shrine keep hidden?','Disturbed graves and the sealed chapel expose burial rites that separated names from memory. Anwen admits the danger she contained by hiding the account.','Release, redirect, or temporarily contain memory without pretending silence is a cure.'),
 ('main_teeth_in_rain','Teeth in the Rain','Why is the binding failing now?','Oren restored a name under the paint of an older token. The hidden road could not keep that memory disordered. Failed containment drew creatures and Vargan\'s recovery patrol.','Protect the living while deciding what happens to an intimate memory fragment.'),
 ('main_names_they_burned','The Names They Burned','Who may share a family\'s story?','The register joins the tokens to a promise of sanctuary. Rook protects family addresses while Edric announces grain conditional on a renewed covenant.','Make wrongdoing known without turning vulnerable families into targets.'),
 ('main_ash_at_the_mill','Ash at the Mill','What does restitution cost people who need food now?','Greyfen ground refugee ash into its fields. The mill still supplies households that did not choose its founding crime. Copies of the ledger survive every operational choice.','Choose closure, supervised supply, or clean repair and restitution.'),
 ('main_soldier_without_banner','A Soldier Without a Banner','Can testimony establish responsibility without purchasing absolution?','Senn admits closing the war road after Halvern refused. His present raids make historical injury a continuing excuse.','Preserve the account while deciding custody, exile, or execution.'),
 ('main_blood_under_stone','Blood Under Stone','What makes Edric\'s emergency plan another concealment?','The command ledger proves sanctuary and closure. Edric admits six years of suppression and proposes ration-backed assent to hide the road again.','Challenge his power, seek voluntary cooperation, or compel evidence without calling it consent.'),
 ('main_last_witness','The Last Witness','What could obedience have refused?','Halvern holds a bounded memory of the sanctuary order, refusal, and execution. Kael admits that he abandoned a different escort and never went back.','Keep guaranteed command proof and accept responsibility for the people still on the road.'),
 ('main_crowns_without_mercy','Crowns Without Mercy','Can people speak freely while protection depends on agreement?','At the assembly the grain list is separated from assent. The unstable renewal is stopped, and records are distinguished from voluntary promises.','Aid and safe departure must remain available to households that refuse.'),
 ('main_hart_remembers','The Hart Remembers','What work begins when the Hart\'s burden ends?','The complete witness remembers the gate, hidden road, and soldiers as distinct decisions. Kael can preserve an account; he cannot promise for Greyfen.','Choose public witness, private release, voluntary stewardship, or destruction with understood costs.')]
evidence = []
def ev(eid, title, text, kind, source, zone, quest=None, objective=None, flag=None, value=True):
    row = {'id':eid,'title':title,'text':text,'kind':kind,'source':source,'zone':zone}
    row['gate'] = {'quest':quest,'objective':objective} if quest else {'flag':flag,'value':value}
    evidence.append(row)
ev('bram','Bram stayed with the cart','Bram\'s marked tool and the repair traces place him at the damaged axle. He did not simply abandon the wagon.','observed','Cart tool and ledger','wychwood','main_road_of_crows','bram')
ev('sella','The shrine thread','Sella\'s feathers carry thread Anwen identifies as hers. The shrine attempted containment before the attack.','observed','Red-thread feathers','wychwood','main_road_of_crows','sella')
ev('oren','Paint over an older name','Oren\'s painted crow covers an older name token. Its scratch marks follow restoration rather than random damage.','observed','Child\'s token','wychwood','main_road_of_crows','oren')
ev('vargan_wire','A second containment','Vargan binding wire is wrapped around the token. It links the aftermath to a recovery patrol, not proof that Edric ordered the original attack.','observed','Binding wire','wychwood','main_road_of_crows','vargan_wire')
ev('drag_marks','Belongings before food','Drag marks leave food sacks and follow identity-bearing objects. The creatures gathered testimony.','inference','Clearing approach','wychwood','main_road_of_crows','drag_marks')
ev('grave_harl','Harl\'s road mud','Road mud lies inside Harl\'s disturbed grave. The bell carries a gate memory rather than an intact returned husband.','observed','Harl\'s grave','cemetery','main_bell_beneath_greyfen','grave_harl')
ev('grave_child','Thread under the earth','The unnamed grave has shrine thread tied from within. Burial rites were keeping memory disordered.','observed','Child\'s grave','cemetery','main_bell_beneath_greyfen','grave_child')
ev('grave_soldier','A Vargan buckle','The empty soldier\'s grave holds Vargan work. A limited watch fragment can carry a fact without becoming a consenting living witness.','observed','Empty soldier\'s grave','cemetery','main_bell_beneath_greyfen','grave_soldier')
ev('crisis_cause','Why this road failed now','Recent repairs uncovered tokens. A restored name strained concealment, failed shrine containment left memory loose, and Vargan tried to reclaim the objects.','testimony','Anwen, Mira, and the restored token','wychwood',flag='crisis_cause_known')
ev('renewal_order','Grain beside assent','Edric\'s current order places grain allotments beside household assent. A ration condition cannot create a freely witnessed oath.','observed','Renewal proclamation','greyfen',flag='renewal_announced')
ev('mill_accounts','Useful ash and stolen weight','The mill\'s weights match the missing refugee wagons. Its channels still support innocent households; the account survives decisions about continued operation.','observed','Mill measure and ledger','old_mill','main_ash_at_the_mill','inspect_millstones')
ev('senn_account','The officer who closed the road','Senn says he closed the military retreat after Halvern refused. The admission establishes his role without excusing present raids.','testimony','Senn\'s signed account','bandit_road',flag='senn_account_recovered')
ev('command_proof','Sanctuary followed by closure','The command and register establish sanctuary promised under a Vargan seal, Greyfen\'s closed gate, shrine concealment, and the military order.','observed','Copied command ledger and bounded refusal','castle_vargan',flag='command_proof_recovered')
ev('kael_confession','A different road','Kael admits obeying a retreat that abandoned civilians he had promised to escort. He left his failure out of the report and never went back.','testimony','Kael\'s own account','undercroft',flag='kael_confessed')
ev('renewal_stopped','Help without a signature','The ration condition is removed at the assembly. Household refusal no longer forfeits food or a safe way out.','observed','Assembly grain list','greyfen',flag='renewal_stopped')
endings = [
 {'id':'expose','title':'Witness','intention':'Make the account public and remain responsible for keeping it.','benefit':'The dead receive public recognition; the Hart leaves judgment to living people.','cost':'Greyfen loses shelter for old privileges. Restitution and safe trade take labor; without allies Kael must remain to preserve the record.','minimum':'Kael plus guaranteed main-path proof.','procedure':'Publicly present the account. Voluntary witnesses share the work; records do not consent.'},
 {'id':'free','title':'Mercy','intention':'Release the Hart while safeguarding intimate memories and vulnerable family identities.','benefit':'The Hart\'s captivity ends without forcing private grief into every household.','cost':'A smaller circle must preserve complete copies. Public acknowledgment is partial, and future neglect can leave grievances unresolved.','minimum':'Kael plus guaranteed main-path proof.','procedure':'The Hart accepts a safeguarded account and an uncoerced keeper. Proven institutional wrongdoing stays on record.'},
 {'id':'bind','title':'Duty','intention':'Freely carry the unresolved binding without pledging anyone else.','benefit':'Greyfen gains immediate stability and time for repairs; the record survives openly.','cost':'Kael\'s freedom and rest become limited. He carries continuing memory while restitution remains unfinished.','minimum':'Kael plus guaranteed main-path proof.','procedure':'Defend a containment rite and accept stewardship voluntarily. Support shares practical work, never another person\'s consent.'},
 {'id':'kill','title':'Ash','intention':'Destroy the supernatural witness while preserving recovered human proof.','benefit':'The Hart\'s immediate pressure ends; people can rebuild without its demand.','cost':'The complete account is lost forever. Dispersed memory harms land and future harvests; copies cannot recover every missing name.','minimum':'Kael plus guaranteed main-path proof.','procedure':'Fight the Hart Avatar. Destruction is force, not a consensual replacement oath; human accountability may continue.'}]
decisions = []
for key, flag in [('miller_record','mill_operation'),('names_decision','names_policy'),('edric_campaign','edric_stance'),('crow_shrine_choice','crow_shrine_state'),('bog_core_choice','bog_core_fate'),('captain_senn','senn_fate'),('assembly_choice','confession_method')]:
    actions = [a for a in c[key].get('actions',[]) if flag in a.get('sets_flags',{})]
    decisions.append({'id':key,'title':c[key]['name'],'flag':flag,'outcomes':[{'value':a['sets_flags'][flag],'label':a['label'],'cost':a['result'],'result':a['result']} for a in actions]})
for key, flag in [('mira','mira_truth'),('blacksmith_tor','iron_fate'),('rook','rook_disclosure'),('widow_elna','widow_truth'),('farmer_toma','guardian_plan')]:
    actions = [a for a in d[key].get('actions',[]) if flag in a.get('sets_flags',{})]
    decisions.append({'id':key,'title':d[key]['name'],'flag':flag,'outcomes':[{'value':a['sets_flags'][flag],'label':a['label'],'cost':a['result'],'result':a['result']} for a in actions]})
campaign = {'version':2,'title':'Ashen Oath: The Road Between Crowns','premise':'Stay with the living when their safety depends on a lie about the dead.','chapters':[dict(zip(['quest_id','title','question','summary','stakes'],row)) for row in chapters],'evidence':evidence,'decisions':decisions,'endings':endings,'consent_rules':['A document establishes facts and cannot promise for its owner.','Protected voluntary testimony remains voluntary only while food and safe departure do not depend on assent.','Compelled admissions may support the record, never a magical covenant.','Kael can pledge his own future work; he cannot bind Greyfen by being its hunter.'],'optional_stories':{'deep':sorted(deep),'interludes':['side_empty_grave','side_childs_charm','side_millers_measure','side_three_candles']}}
write('story_campaign.json', campaign)
