import 'package:jass_engine/jass_engine.dart';

import '../l10n/generated/app_localizations.dart';

/// Uebersetzt Spielbegriffe und Ereignisse in Text. Die Engine kennt keine Texte.
extension GameTexts on AppLocalizations {
  String suit(Suit suit) => suitName(suit.name);

  String rank(Rank rank) => rankName(rank.name);

  String card(JassCard card) => cardName(suit(card.suit), rank(card.rank));

  String mode(RoundMode mode) => modeName(mode.name);

  /// "Rosen Trumpf" bzw. "Obe-Abe".
  String modeWithTrump(RoundMode mode) =>
      mode.isTrump ? modeTrump(modeName(mode.name)) : mode_(mode);

  String mode_(RoundMode mode) => modeName(mode.name);

  /// Spielart mit Multiplikator, zum Beispiel "Schilten ×2"; im Slalom zusaetzlich der laufende Stich.
  String modeChip(GameState game) {
    final roundMode = game.roundMode;
    if (roundMode == null) {
      return '';
    }
    final label = roundMode.isSlalom
        ? '${mode(roundMode.base)} · ${mode(game.trickMode!)}'
        : modeWithTrump(roundMode);
    final factor = game.roundMultiplier;
    return factor > 1 ? '$label ${multiplier(factor)}' : label;
  }

  String weis(Weis weis) => switch (weis.type) {
    WeisType.sequence => weisDescribeSequence(
      weis.points,
      suit(weis.suit!),
      rank(weis.lowRank),
      rank(weis.highRank),
    ),
    WeisType.fourOfKind => weisDescribeFourOfKind(weis.points, rank(weis.relevantRank)),
  };

  String variant(GameVariant variant) => variantName(variant.name);

  /// Teamname wie in der Web-App: beim eigenen Team steht der Partner zuerst.
  String team(GameState game, int teamId) {
    final ids = game.teams.firstWhere((team) => team.id == teamId).playerIds;
    final ordered = ids.contains(0) ? [ids.last, ids.first] : ids;
    return teamName(game.players[ordered[0]].name, game.players[ordered[1]].name);
  }

  /// Bieterjass: die beiden, die zusammen gegen den Bieter spielen.
  String pairName(GameState game) {
    final names = [
      for (final player in game.players)
        if (player.id != game.soloPlayer) player.name,
    ];
    return names.length == 2 ? teamName(names[0], names[1]) : names.join(' & ');
  }

  String playerOrTeam(GameState game, int playerIndex) => game.isSchieber
      ? team(game, game.players[playerIndex].teamId)
      : game.players[playerIndex].name;

  String pileLabel(GameState game, int pileId) {
    if (game.isSchieber) {
      return pileId == 0 ? pileOwnTeam : pileOpponentTeam;
    }
    if (game.soloPlayer >= 0) {
      return pileId == 0 ? game.players[game.soloPlayer].name : pileDefenders;
    }
    return pileId == 0 ? pileBidder : pileOpponents;
  }

  /// Abzeichen neben dem Namen: Geber, Partner, Gebot oder Pass.
  String seatBadge(GameState game, int playerIndex) {
    final player = game.players[playerIndex];
    if (game.isBieter) {
      if (game.soloPlayer >= 0) {
        return [
          if (playerIndex == game.soloPlayer) badgeSolo(game.soloTarget) else badgePair,
          if (playerIndex == game.dealer) badgeDealer,
        ].join(' · ');
      }
      if (player.bid == null) {
        return playerIndex == game.dealer ? badgeDealer : '';
      }
      return player.bid == 0 ? badgePass : badgeBid(player.bid!);
    }
    return [
      if (playerIndex == partnerOf(game, 0)) badgePartner,
      if (playerIndex == game.dealer) badgeDealer,
    ].join(' · ');
  }

  /// Hinweiszeile ueber dem Tisch, je nach Phase und wer am Zug ist.
  String phaseMessage(GameState game) {
    final current = game.players[game.currentPlayer];
    switch (game.phase) {
      case GamePhase.bidding:
        return current.isHuman ? msgBiddingHuman : msgBiddingAi(current.name);
      case GamePhase.chooseTrump:
        if (current.isHuman) {
          return canPushTrump(game) ? msgChooseModeHumanPush : msgChooseModeHuman;
        }
        return msgChooseModeAi(current.name);
      case GamePhase.announceWeis:
        if (current.isHuman) {
          final options = game.weisState?.possibleByPlayer[game.currentPlayer] ?? const [];
          return options.isEmpty ? msgWeisHumanNone : msgWeisHuman;
        }
        return msgWeisAi(current.name);
      case GamePhase.playing:
        return current.isHuman ? msgPlayingHuman : msgPlayingAi(current.name);
      case GamePhase.trickEnd:
        return msgTrickEnd(game.players[game.trickLeader].name);
      case GamePhase.roundEnd:
        return switch (game.roundSummary) {
          BieterRoundSummary(:final soloPlayer, :final soloPoints, :final pairPoints) =>
            msgRoundEndBieter(game.players[soloPlayer].name, soloPoints, pairPoints),
          SchieberRoundSummary(:final roundWinnerTeamId) => msgRoundEndSchieber(
            team(game, roundWinnerTeamId),
          ),
          null => '',
        };
      case GamePhase.gameOver:
        if (game.isBieter) {
          final solo = game.players[game.soloPlayer];
          return solo.totalScore >= game.soloTarget
              ? msgGameOverBieterSolo(solo.name, game.soloTarget)
              : msgGameOverBieterPair(pairName(game), game.pairTarget);
        }
        final winner = game.teams.reduce((a, b) => b.totalScore > a.totalScore ? b : a);
        return msgGameOverSchieber(team(game, winner.id));
      case GamePhase.setup:
        return '';
    }
  }

  String restriction(PlayRestriction restriction, GameState game) => switch (restriction) {
    PlayRestriction.notInHand ||
    PlayRestriction.mustFollowSuit => restrictionMustFollowSuit(suit(game.trick.first.card.suit)),
    PlayRestriction.mustFollowTrump => restrictionMustFollowTrump,
    PlayRestriction.noUndertrump => restrictionNoUndertrump,
  };

  /// Ein Ereignis als Satz fuer den Verlauf; `null` fuer Ereignisse ohne Zeile.
  String? logLine(GameState game, GameEvent event) {
    String name(int seat) => game.players[seat].name;
    return switch (event) {
      RoundStarted(:final roundNumber, :final dealer) => logRoundStarted(roundNumber, name(dealer)),
      BidPlaced(:final playerIndex, :final value) => logBidPlaced(name(playerIndex), value),
      BidPassed(:final playerIndex) => logBidPassed(name(playerIndex)),
      BiddingWon(:final playerIndex, :final bid, :final allPassed) =>
        allPassed
            ? logBiddingForced(name(playerIndex), bid)
            : logBiddingWon(name(playerIndex), bid),
      TrumpPushed(:final fromPlayer, :final toPlayer) => logTrumpPushed(
        name(fromPlayer),
        name(toPlayer),
      ),
      ModeChosen(:final playerIndex, :final mode) => logModeChosen(
        name(playerIndex),
        modeWithTrump(mode),
      ),
      WeisDeclared(:final playerIndex, :final weis) =>
        weis == null
            ? logWeisNone(name(playerIndex))
            : logWeisDeclared(name(playerIndex), this.weis(weis)),
      WeisAwarded(:final teamId, :final points) => logWeisAwarded(team(game, teamId), points),
      NoWeisAwarded() => logNoWeis,
      StoeckAnnounced(:final playerIndex, :final points) => logStoeck(name(playerIndex), points),
      CardPlayed(:final playerIndex, :final card) => logCardPlayed(
        name(playerIndex),
        this.card(card),
      ),
      TrickWon(:final winner, :final points, :final trickNumber) => logTrickWon(
        trickNumber,
        name(winner),
        points,
      ),
      RoundScored() => logRoundScored,
      GameOver() => logGameOver,
      NextTrickStarted() => null,
    };
  }

  /// Die Zeilen der Rundenabrechnung.
  List<String> roundSummaryLines(GameState game) {
    final summary = game.roundSummary;
    if (summary == null) {
      return const [];
    }
    final factor = summary.multiplier > 1 ? ' ${multiplier(summary.multiplier)}' : '';
    final modeLine = summaryMode('${mode(summary.roundMode)}$factor');

    switch (summary) {
      case BieterRoundSummary():
        return [
          modeLine,
          summaryBieterSide(
            game.players[summary.soloPlayer].name,
            summary.soloPoints,
            summary.soloTotal,
            summary.bid,
          ),
          summaryBieterSide(
            pairName(game),
            summary.pairPoints,
            summary.pairTotal,
            summary.pairTarget,
          ),
        ];
      case SchieberRoundSummary():
        String teamLine(TeamRoundResult result) {
          final parts = [
            summaryTrickPoints(result.trickPoints),
            if (result.weisPoints > 0) summaryWeisPoints(result.weisPoints),
            if (result.stoeckPoints > 0) summaryStoeckPoints(result.stoeckPoints),
            if (result.matchPoints > 0) summaryMatchPoints(result.matchPoints),
          ].join(' + ');
          return summaryTeamLine(
            team(game, result.teamId),
            parts,
            result.basePoints,
            factor,
            result.roundPoints,
          );
        }

        final weisWinner = summary.weisWinnerTeamId;
        final weisPoints = weisWinner == null
            ? 0
            : summary.results.firstWhere((result) => result.teamId == weisWinner).weisPoints;
        return [
          modeLine,
          for (final result in summary.results) teamLine(result),
          summaryRoundWinner(team(game, summary.roundWinnerTeamId)),
          if (weisWinner != null && summary.highestWeis != null)
            summaryWeisWinner(team(game, weisWinner), weisPoints, weis(summary.highestWeis!))
          else
            summaryWeisNone,
          if (summary.stoeckPlayer >= 0 && game.stoeckAnnounced)
            summaryStoeck(game.players[summary.stoeckPlayer].name, game.rules.stoeckPoints),
          if (summary.matchTeamId != null)
            summaryMatch(team(game, summary.matchTeamId!), game.rules.matchBonus),
          if (summary.pushed) summaryPushed(game.players[summary.trumpChooser].name),
        ];
    }
  }

  /// Rangliste am Spielende.
  List<String> rankingLines(GameState game) {
    if (game.isBieter) {
      final solo = game.players[game.soloPlayer];
      final soloLine = rankingBieter(solo.name, solo.totalScore, game.soloTarget);
      final pairLine = rankingBieter(pairName(game), game.pairScore, game.pairTarget);
      return solo.totalScore >= game.soloTarget ? [soloLine, pairLine] : [pairLine, soloLine];
    }
    final ranked = [...game.teams]..sort((a, b) => b.totalScore - a.totalScore);
    return [
      gameOverTarget(game.targetScore),
      for (var index = 0; index < ranked.length; index += 1)
        rankingLine(index + 1, team(game, ranked[index].id), ranked[index].totalScore),
    ];
  }
}
