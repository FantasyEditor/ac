function ac.game:message(data)
    for player in ac.each_player 'user' do
        player:message(data)
    end
end
