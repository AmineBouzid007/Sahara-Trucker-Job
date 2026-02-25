// ==========================================
// [01] GLOBAL STATE
// ==========================================
let soloJobList = [];
let convoyJobList = [];
let myServerID = null;
let currentConvoyID = null;
let isLeader = false;
let memberCount = 0;
let playerLevel = 1;
let currentJobId = null;

// ==========================================
// [02] INITIALIZATION
// ==========================================
$(document).ready(function () {

    $('#ui-wrapper, .popUp, .page-container').hide();
    $('#jobsPage').show();

    if ($('#player-count').length === 0) {
        const lobbyPanel = $('.lobby-panel').first();
        lobbyPanel.append('<div id="player-count">0/4</div>');
        lobbyPanel.append('<div id="start-convoy-job-btn" class="confirm disabled">Start Job</div>');
    }

    // NAVIGATION
    $('.nav-item').on('click', function () {

        const targetPage = $(this).data('page');

        $('.nav-item').removeClass('active');
        $(this).addClass('active');

        $('.page-container').hide();
        $('#' + targetPage).fadeIn(200);

        if (targetPage === 'jobsPage') loadSoloJobs();
        if (targetPage === 'convoyPage') loadConvoyJobs();
    });

    $('#closeBtn, .closeIcon').on('click', closeMenu);
    $('#cancel').on('click', () => $('.popUp').fadeOut(200));

    // ==========================================
    // SOLO JOB START
    // ==========================================
    $('#confirm').on('click', function () {

        if (!currentJobId) return;

        const selectedJob = soloJobList.find(j => j.id === currentJobId);
        if (!selectedJob) return;

        $.post(`https://${GetParentResourceName()}/startSoloJob`, JSON.stringify({
            jobId: selectedJob.id,
            jobType: selectedJob.type
        }));

        $('.popUp').fadeOut(200);
        closeMenu();
    });

    // FILTER
    $('.filterMenu').on('click', () => $('.menu-items').fadeToggle(150));

    $('#asc').on('click', () => { soloJobList.sort((a,b)=>a.totalPrice-b.totalPrice); loadSoloJobs(); });
    $('#desc').on('click', () => { soloJobList.sort((a,b)=>b.totalPrice-a.totalPrice); loadSoloJobs(); });
    $('#farthest').on('click', () => { soloJobList.sort((a,b)=>b.distance-a.distance); loadSoloJobs(); });
    $('#shortest').on('click', () => { soloJobList.sort((a,b)=>a.distance-b.distance); loadSoloJobs(); });

    $('#trailerInput').on('keyup', function () {

        const val = $(this).val().toLowerCase();

        $("#jobListArea .trailerItem").each(function () {
            $(this).toggle($(this).text().toLowerCase().indexOf(val) > -1);
        });

    });

    // ==========================================
    // CONVOY START
    // ==========================================
$('#start-convoy-job-btn').on('click', function () {
    if ($(this).hasClass('disabled')) {
        $.post(`https://${GetParentResourceName()}/notify`, JSON.stringify({
            type: 'error',
            message: 'Select a contract and have at least 1 member.'
        }));
        return;
    }

    // Send the convoy ID to the server
    $.post(`https://${GetParentResourceName()}/requestConvoyStart`, JSON.stringify({
        convoyID: currentConvoyID
    }));
});
});

// ==========================================
// [03] NUI MESSAGE HANDLER
// ==========================================
window.addEventListener('message', function (event) {

    const data = event.data;

    switch (data.action) {

        case "openUI":

            myServerID = data.serverID;

            soloJobList = (data.soloJobs?.static || []).concat(data.soloJobs?.random || []);
            convoyJobList = data.convoyJobs || [];

            if (data.player) {
                $('#playerName').text("USER_REF: " + data.player.name);
                updateLevelUI(data.player.xp, data.player.level);
            }

            $('.nav-item[data-page="jobsPage"]').click();

            $('#ui-wrapper').css('display', 'flex').hide().fadeIn(300);

        break;

        case "updateConvoyPlayers":

            currentConvoyID = data.convoyID || currentConvoyID;

            const members = data.members || [];
            memberCount = members.length;

            const me = members.find(m => m.id === myServerID);
            isLeader = me && me.isLeader === true;

            if (currentConvoyID) {

                $('#convoyAuth').hide();
                $('#convoyLobby').show();

                $('#activeConvoyID').text("#" + currentConvoyID);

                renderLobbyPlayers(members);

                $('#player-count').text(memberCount + '/4');
            }

            loadConvoyJobs();
            updateStartButtonState();

        break;

        case "syncConvoyJob":

            if (data.jobData && !isLeader) {
                currentJobId = data.jobData.id;
                loadConvoyJobs();
            }

        break;

        case "resetConvoy":

            resetConvoyUI();

        break;

        case "close":

            closeMenu();

        break;
    }

});

// ==========================================
// [04] CONVOY SYSTEM
// ==========================================
function updateStartButtonState() {

    const startButton = $('#start-convoy-job-btn');

    if (isLeader && memberCount >= 1 && currentJobId !== null) {
        startButton.removeClass('disabled');
    } else {
        startButton.addClass('disabled');
    }

}

$('#createConvoyBtn').on('click', () => {
    $.post(`https://${GetParentResourceName()}/createConvoy`, JSON.stringify({}));
});

$('#joinConvoyBtn').on('click', () => {

    const id = $('#joinIDInput').val();

    if (!id) return;

    $.post(`https://${GetParentResourceName()}/joinConvoy`, JSON.stringify({
        convoyID: id
    }));

});

$('#leaveConvoyBtn').on('click', () => {

    $.post(`https://${GetParentResourceName()}/leaveConvoy`, JSON.stringify({}));
    resetConvoyUI();

});

function resetConvoyUI() {

    currentConvoyID = null;
    isLeader = false;
    currentJobId = null;
    memberCount = 0;

    $('#convoyLobby').hide();
    $('#convoyAuth').show();

    $('#player-count').text('0/4');

    updateStartButtonState();
    loadConvoyJobs();

}

function renderLobbyPlayers(players) {

    const container = $('#playerList');
    container.empty();

    players.forEach(p => {

        container.append(`
            <div class="player-row">
                <span>${p.name}</span>
                <span class="player-id">[SIG_${p.id}]</span>
            </div>
        `);

    });

}

// ==========================================
// [05] SOLO JOB RENDER
// ==========================================
function loadSoloJobs() {

    const container = $('#jobListArea');
    container.empty();

    if (soloJobList.length === 0) {
        container.append('<div class="job-lock-overlay"><span>NO CONTRACTS AVAILABLE</span></div>');
        return;
    }

    soloJobList.forEach(function (job) {

        const reqRank = job.level || 1;
        const isLocked = playerLevel < reqRank;
        let activeClass = (currentJobId === job.id) ? 'active' : '';

        let html = `
        <div class="trailerItem ${isLocked ? 'locked' : ''} ${activeClass}" data-id="${job.id}">
            ${isLocked ? `<div class="locked-overlay">REQUIRED RANK ${reqRank}</div>` : ''}
            <div class="trailerImg"><img src="${job.imgSrc}"></div>
            <div class="trailerInfo">
                <div class="trailerName">${job.name}</div>
                <div class="trailerRoute">${job.streetNames || "INDUSTRIAL"}</div>
            </div>
            <div class="trailerStats">
                <div class="trailerPrice">$${job.totalPrice}</div>
                <div class="trailerDist">${job.distance || 5} KM</div>
            </div>
        </div>
        `;

        const $item = $($.parseHTML(html));

        $item.on('click', function () {

            if (isLocked) return;

            currentJobId = job.id;

            $('#jobListArea .trailerItem').removeClass('active');
            $(this).addClass('active');

            $('.popUpText').html(`AUTHORIZE CONTRACT: <span style="color:#00d2ff">${job.name}</span>?`);
            $('.popUp').fadeIn(200);

        });

        container.append($item);

    });

}

// ==========================================
// [06] CONVOY JOB RENDER
// ==========================================
function loadConvoyJobs() {

    const container = $('#lobbyMissionInfo');
    container.empty();

    if (!currentConvoyID) {
        container.html('<div class="no-mission">WAITING FOR CONVOY...</div>');
        return;
    }

    if (!isLeader) {
        container.html('<div class="no-mission">LEADER SELECTING CONTRACT...</div>');
        return;
    }

    if (convoyJobList.length === 0) {
        container.html('<div class="no-mission">NO CONVOY JOBS</div>');
        return;
    }

    container.html('<div class="convoy-job-scroll"></div>');
    const scroll = container.find('.convoy-job-scroll');

    convoyJobList.forEach(function (job) {

        let activeClass = (currentJobId === job.id) ? 'active' : '';

        const html = `
        <div class="convoy-job-item ${activeClass}" data-id="${job.id}">
            <div class="convoy-job-name">${job.name}</div>
            <div class="convoy-job-details">
                <span>$${job.totalPrice}</span>
                <span>${job.distance} KM</span>
                <span>RANK ${job.level || 1}</span>
            </div>
        </div>
        `;

        const $item = $($.parseHTML(html));

        $item.on('click', function () {

            if (!isLeader) return;

            currentJobId = job.id;

            $('.convoy-job-item').removeClass('active');
            $(this).addClass('active');

            $.post(`https://${GetParentResourceName()}/selectJob`, JSON.stringify({
                convoyID: currentConvoyID,
                jobData: job
            }));

            updateStartButtonState();

        });

        scroll.append($item);

    });

}

// ==========================================
// [07] UI HELPERS
// ==========================================
function updateLevelUI(xp, level) {

    playerLevel = level;

    $('#levelStatus').css('width', xp + '%');
    $('#levelText').text(`RANK ${level} [${xp}/100 XP]`);

}

function closeMenu() {

    $('#ui-wrapper, .popUp').fadeOut(200, function () {
        $(this).hide();
    });

    $.post(`https://${GetParentResourceName()}/closeUI`, JSON.stringify({}));

    currentJobId = null;

}
