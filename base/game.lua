function ac.game:message(data)
    for player in ac.each_player 'user' do
        player:message(data)
    end
end

function ac.game:get_winner_team()
    return ac.team(self:get_winner())
end
